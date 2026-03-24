import React, { useState, useEffect, useRef } from 'react';
import { db, Message } from '../lib/db';
import { meshManager } from '../lib/mesh';
import { useLiveQuery } from 'dexie-react-hooks';
import { Theme } from '../lib/theme';
import { t, Lang } from '../lib/i18n';
import { Avatar, Button, Modal } from './ui';
import {
  ArrowLeft, Send, Mic, Plus, Search, MoreVertical, Check, CheckCheck,
  Image as ImageIcon, Paperclip, MapPin, Phone, Video, Smile, X, Edit3, Trash2
} from 'lucide-react';

const REACTIONS = ['👍','❤️','😂','😮','😢','🙏'];

export default function ChatWindow({ chatId, onBack, myId, theme, lang, onStartCall }: {
  chatId: string; onBack: () => void; myId: string; theme: Theme; lang: Lang;
  onStartCall?: (contactId: string, video: boolean) => void;
}) {
  const chat = useLiveQuery(() => db.chats.get(chatId));
  const contact = useLiveQuery(() => db.contacts.get(chatId));
  const contacts = useLiveQuery(() => db.contacts.toArray());
  const messages = useLiveQuery(() => db.messages.where('chatId').equals(chatId).sortBy('timestamp'));
  const [inputText, setInputText] = useState('');
  const [showAttach, setShowAttach] = useState(false);
  const [showReactions, setShowReactions] = useState<string | null>(null);
  const [editingMsg, setEditingMsg] = useState<string | null>(null);
  const [editText, setEditText] = useState('');
  const [contextMenu, setContextMenu] = useState<{ msgId: string; x: number; y: number } | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const imgInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => { messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);
  useEffect(() => { db.chats.update(chatId, { unreadCount: 0 }); }, [chatId]);

  const chatName = chat?.type === 'group' ? (chat.name || 'Group') : (contact?.displayName || chatId);

  const handleSend = async () => {
    if (!inputText.trim()) return;
    if (editingMsg) {
      await db.messages.update(editingMsg, { text: inputText, isEdited: true });
      setEditingMsg(null); setEditText('');
    } else {
      await meshManager.sendMessage(chatId, inputText);
    }
    setInputText('');
  };

  const handleImagePick = () => { imgInputRef.current?.click(); setShowAttach(false); };
  const handleFilePick = () => { fileInputRef.current?.click(); setShowAttach(false); };

  const handleImageSelected = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]; if (!file) return;
    const reader = new FileReader();
    reader.onload = async () => {
      const base64 = reader.result as string;
      // Compress by drawing to canvas
      const img = new window.Image();
      img.onload = async () => {
        const canvas = document.createElement('canvas');
        const maxDim = 1280;
        let w = img.width, h = img.height;
        if (w > maxDim || h > maxDim) {
          if (w > h) { h = (h / w) * maxDim; w = maxDim; }
          else { w = (w / h) * maxDim; h = maxDim; }
        }
        canvas.width = w; canvas.height = h;
        canvas.getContext('2d')?.drawImage(img, 0, 0, w, h);
        const compressed = canvas.toDataURL('image/jpeg', 0.85);
        await meshManager.sendMessage(chatId, '📷 Image', { mediaType: 'image', mediaData: compressed });
      };
      img.src = base64;
    };
    reader.readAsDataURL(file);
  };

  const handleFileSelected = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]; if (!file) return;
    const reader = new FileReader();
    reader.onload = async () => {
      const base64 = reader.result as string;
      await meshManager.sendMessage(chatId, `📎 ${file.name}`, { mediaType: 'file', mediaData: base64 });
    };
    reader.readAsDataURL(file);
  };

  const handleShareLocation = () => {
    setShowAttach(false);
    navigator.geolocation.getCurrentPosition(async (pos) => {
      const locData = JSON.stringify({ lat: pos.coords.latitude, lng: pos.coords.longitude });
      await meshManager.sendMessage(chatId, '📍 Location', { mediaType: 'location', mediaData: locData });
    });
  };

  const handleVoiceRecord = async () => {
    if (isRecording) { setIsRecording(false); return; }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const recorder = new MediaRecorder(stream);
      const chunks: Blob[] = [];
      recorder.ondataavailable = (e) => chunks.push(e.data);
      recorder.onstop = async () => {
        const blob = new Blob(chunks, { type: 'audio/webm' });
        const reader = new FileReader();
        reader.onload = async () => {
          await meshManager.sendMessage(chatId, '🎤 Voice note', { mediaType: 'audio', mediaData: reader.result as string });
        };
        reader.readAsDataURL(blob);
        stream.getTracks().forEach(t => t.stop());
      };
      setIsRecording(true);
      recorder.start();
      setTimeout(() => { if (recorder.state === 'recording') { recorder.stop(); setIsRecording(false); } }, 60000);
      // Store recorder ref
      (window as any).__meshRecorder = recorder;
    } catch (e) { console.error('Mic access denied', e); }
  };

  const stopRecording = () => {
    const rec = (window as any).__meshRecorder;
    if (rec && rec.state === 'recording') rec.stop();
    setIsRecording(false);
  };

  const handleReaction = async (msgId: string, emoji: string) => {
    const msg = await db.messages.get(msgId);
    if (!msg) return;
    const reactions = { ...(msg.reactions || {}), [myId]: emoji };
    await db.messages.update(msgId, { reactions });
    setShowReactions(null);
  };

  const handleDelete = async (msgId: string) => {
    await db.messages.delete(msgId);
    setContextMenu(null);
  };

  const handleEdit = async (msg: Message) => {
    if (msg.direction === 'sent' && (Date.now() - msg.timestamp) < 600000) {
      setEditingMsg(msg.id);
      setEditText(msg.text);
      setInputText(msg.text);
    }
    setContextMenu(null);
  };

  const renderMedia = (msg: Message) => {
    if (msg.mediaType === 'image' && msg.mediaData) {
      return <img src={msg.mediaData} alt="sent" className="rounded-lg max-w-full max-h-64 mb-1" />;
    }
    if (msg.mediaType === 'audio' && msg.mediaData) {
      return <audio controls src={msg.mediaData} className="max-w-full mb-1" />;
    }
    if (msg.mediaType === 'file' && msg.mediaData) {
      return (
        <a href={msg.mediaData} download className="flex items-center gap-2 p-2 rounded mb-1"
          style={{ backgroundColor: theme.bgTertiary }}>
          <Paperclip size={16} /><span className="text-sm underline">{t(lang, 'file')}</span>
        </a>
      );
    }
    if (msg.mediaType === 'location' && msg.mediaData) {
      try {
        const loc = JSON.parse(msg.mediaData);
        return (
          <a href={`https://www.openstreetmap.org/?mlat=${loc.lat}&mlon=${loc.lng}#map=15/${loc.lat}/${loc.lng}`}
            target="_blank" rel="noopener" className="flex items-center gap-2 p-2 rounded mb-1"
            style={{ backgroundColor: theme.bgTertiary }}>
            <MapPin size={16} style={{ color: theme.accent }} />
            <span className="text-sm">{loc.lat.toFixed(4)}, {loc.lng.toFixed(4)}</span>
          </a>
        );
      } catch { return null; }
    }
    return null;
  };

  return (
    <div className="flex-1 flex flex-col h-full" style={{ backgroundColor: theme.bgChat }}>
      {/* Header */}
      <header className="p-3 flex items-center gap-4 shadow-md z-10" style={{ backgroundColor: theme.bgSecondary }}>
        <button onClick={onBack} className="md:hidden" style={{ color: theme.textMuted }}><ArrowLeft size={24} /></button>
        <Avatar name={chatName} theme={theme} />
        <div className="flex-1 min-w-0">
          <h3 className="font-medium truncate" style={{ color: theme.text }}>{chatName}</h3>
          <span className="text-xs" style={{ color: theme.textSecondary }}>
            {chat?.type === 'group' ? `${chat.participants?.length || 0} ${t(lang, 'members')}` : t(lang, 'online')}
          </span>
        </div>
        <div className="flex gap-3" style={{ color: theme.textMuted }}>
          {chat?.type === 'direct' && onStartCall && (
            <>
              <button onClick={() => onStartCall(chatId, false)} className="hover:opacity-70"><Phone size={20} /></button>
              <button onClick={() => onStartCall(chatId, true)} className="hover:opacity-70"><Video size={20} /></button>
            </>
          )}
          <button className="hover:opacity-70"><Search size={20} /></button>
        </div>
      </header>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-2" onClick={() => { setContextMenu(null); setShowReactions(null); }}>
        {messages?.map(msg => (
          <div key={msg.id} className={`flex ${msg.direction === 'sent' ? 'justify-end' : 'justify-start'}`}
            onContextMenu={(e) => { e.preventDefault(); setContextMenu({ msgId: msg.id, x: e.clientX, y: e.clientY }); }}>
            <div className="max-w-[70%] p-2 rounded-lg shadow-sm relative min-w-[80px]"
              style={{
                backgroundColor: msg.direction === 'sent' ? theme.sentBubble : theme.receivedBubble,
                color: theme.text,
                borderTopRightRadius: msg.direction === 'sent' ? 0 : undefined,
                borderTopLeftRadius: msg.direction !== 'sent' ? 0 : undefined,
              }}>
              {chat?.type === 'group' && msg.direction === 'received' && (
                <p className="text-xs font-bold mb-1" style={{ color: theme.accent }}>
                  {contacts?.find(c => c.id === msg.senderId)?.displayName || msg.senderId}
                </p>
              )}
              {renderMedia(msg)}
              {msg.text && !msg.text.startsWith('📷') && !msg.text.startsWith('🎤') && !msg.text.startsWith('📎') && !msg.text.startsWith('📍') && (
                <p className="text-sm pb-4">{msg.text}</p>
              )}
              {msg.text && (msg.text.startsWith('📷') || msg.text.startsWith('🎤') || msg.text.startsWith('📎') || msg.text.startsWith('📍')) && !msg.mediaData && (
                <p className="text-sm pb-4">{msg.text}</p>
              )}
              {/* Reactions display */}
              {msg.reactions && Object.keys(msg.reactions).length > 0 && (
                <div className="flex gap-1 mt-1">
                  {Object.values(msg.reactions).map((r, i) => (
                    <span key={i} className="text-xs rounded-full px-1" style={{ backgroundColor: theme.bgTertiary }}>{r}</span>
                  ))}
                </div>
              )}
              <div className="absolute bottom-1 right-2 flex items-center gap-1">
                {msg.isEdited && <span className="text-[9px] italic opacity-50">{t(lang, 'messageEdited')}</span>}
                <span className="text-[10px] opacity-60">{new Date(msg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                {msg.direction === 'sent' && (
                  msg.status === 'pending' ? <span className="text-[10px] opacity-40">⏳</span>
                  : msg.status === 'sent' ? <Check size={14} className="opacity-60" />
                  : <CheckCheck size={14} style={{ color: msg.status === 'read' ? theme.tickRead : undefined }} className={msg.status !== 'read' ? 'opacity-60' : ''} />
                )}
              </div>
              {/* Quick reaction button */}
              <button className="absolute -bottom-2 -left-2 w-6 h-6 rounded-full flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity text-xs"
                style={{ backgroundColor: theme.bgTertiary }}
                onClick={(e) => { e.stopPropagation(); setShowReactions(msg.id); }}>
                <Smile size={12} />
              </button>
            </div>
            {/* Reaction picker */}
            {showReactions === msg.id && (
              <div className="flex gap-1 items-end ml-1 p-1 rounded-lg shadow-lg" style={{ backgroundColor: theme.bgSecondary }}>
                {REACTIONS.map(r => (
                  <button key={r} onClick={() => handleReaction(msg.id, r)} className="text-lg hover:scale-125 transition-transform">{r}</button>
                ))}
              </div>
            )}
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      {/* Context menu */}
      {contextMenu && (
        <div className="fixed z-50 rounded-lg shadow-xl py-2 min-w-[160px]"
          style={{ left: contextMenu.x, top: contextMenu.y, backgroundColor: theme.bgSecondary }}>
          {(() => { const msg = messages?.find(m => m.id === contextMenu.msgId); return msg ? (
            <>
              <button onClick={() => { setShowReactions(contextMenu.msgId); setContextMenu(null); }}
                className="w-full text-left px-4 py-2 flex items-center gap-3 hover:opacity-80 text-sm" style={{ color: theme.text }}>
                <Smile size={16} /> {t(lang, 'reactions')}
              </button>
              {msg.direction === 'sent' && (Date.now() - msg.timestamp) < 600000 && (
                <button onClick={() => handleEdit(msg)}
                  className="w-full text-left px-4 py-2 flex items-center gap-3 hover:opacity-80 text-sm" style={{ color: theme.text }}>
                  <Edit3 size={16} /> {t(lang, 'edit')}
                </button>
              )}
              <button onClick={() => handleDelete(contextMenu.msgId)}
                className="w-full text-left px-4 py-2 flex items-center gap-3 hover:opacity-80 text-sm" style={{ color: theme.danger }}>
                <Trash2 size={16} /> {t(lang, 'delete')}
              </button>
            </>
          ) : null; })()}
        </div>
      )}

      {/* Input */}
      <footer className="p-3 flex items-center gap-3 relative" style={{ backgroundColor: theme.bgSecondary }}>
        {/* Attach menu */}
        <div className="relative">
          <button onClick={() => setShowAttach(!showAttach)} style={{ color: theme.textSecondary }}><Plus size={24} /></button>
          {showAttach && (
            <div className="absolute bottom-12 left-0 rounded-lg shadow-xl py-2 min-w-[150px] z-30" style={{ backgroundColor: theme.bgSecondary }}>
              <button onClick={handleImagePick} className="w-full text-left px-4 py-2 flex items-center gap-3 text-sm hover:opacity-80" style={{ color: theme.text }}>
                <ImageIcon size={16} style={{ color: '#7c3aed' }} /> {t(lang, 'image')}
              </button>
              <button onClick={handleFilePick} className="w-full text-left px-4 py-2 flex items-center gap-3 text-sm hover:opacity-80" style={{ color: theme.text }}>
                <Paperclip size={16} style={{ color: '#3b82f6' }} /> {t(lang, 'file')}
              </button>
              <button onClick={handleShareLocation} className="w-full text-left px-4 py-2 flex items-center gap-3 text-sm hover:opacity-80" style={{ color: theme.text }}>
                <MapPin size={16} style={{ color: '#10b981' }} /> {t(lang, 'location')}
              </button>
            </div>
          )}
        </div>
        <input type="file" ref={imgInputRef} accept="image/*" className="hidden" onChange={handleImageSelected} />
        <input type="file" ref={fileInputRef} className="hidden" onChange={handleFileSelected} />
        <div className="flex-1 rounded-lg px-4 py-2" style={{ backgroundColor: theme.bgTertiary }}>
          <input type="text" placeholder={editingMsg ? t(lang, 'edit') : t(lang, 'typeMessage')}
            value={inputText} onChange={e => setInputText(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && handleSend()}
            className="bg-transparent border-none outline-none w-full text-sm" style={{ color: theme.text }} />
        </div>
        {editingMsg && <button onClick={() => { setEditingMsg(null); setInputText(''); }} style={{ color: theme.danger }}><X size={20}/></button>}
        {inputText.trim() ? (
          <button onClick={handleSend} style={{ color: theme.accent }}><Send size={24} /></button>
        ) : isRecording ? (
          <button onClick={stopRecording} className="animate-pulse" style={{ color: theme.danger }}><Mic size={24} /></button>
        ) : (
          <button onClick={handleVoiceRecord} style={{ color: theme.textSecondary }}><Mic size={24} /></button>
        )}
      </footer>
    </div>
  );
}
