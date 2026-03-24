import React from 'react';
import { db, Chat, Contact } from '../lib/db';
import { useLiveQuery } from 'dexie-react-hooks';
import { Theme } from '../lib/theme';
import { t, Lang } from '../lib/i18n';
import { Avatar } from './ui';

export default function ChatList({ onSelect, activeId, theme, lang }: { onSelect: (id: string) => void; activeId: string | null; theme: Theme; lang: Lang }) {
  const chats = useLiveQuery(() => db.chats.orderBy('createdAt').reverse().toArray());
  const contacts = useLiveQuery(() => db.contacts.toArray());
  const messages = useLiveQuery(() => db.messages.orderBy('timestamp').reverse().toArray());

  if (!chats || chats.length === 0) {
    return <div className="p-8 text-center" style={{ color: theme.textSecondary }}><p>{t(lang, 'noChats')}</p></div>;
  }

  return (
    <div>
      {chats.map(chat => {
        const contact = contacts?.find(c => c.id === chat.id);
        const lastMsg = messages?.find(m => m.chatId === chat.id);
        const name = chat.type === 'group' ? (chat.name || 'Group') : (contact?.displayName || chat.id);
        const preview = lastMsg
          ? (lastMsg.mediaType === 'image' ? '📷 Image'
            : lastMsg.mediaType === 'audio' ? '🎤 Voice note'
            : lastMsg.mediaType === 'file' ? '📎 File'
            : lastMsg.mediaType === 'location' ? '📍 Location'
            : lastMsg.text || 'No messages yet')
          : 'No messages yet';
        const time = lastMsg ? new Date(lastMsg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '';
        return (
          <div key={chat.id} onClick={() => onSelect(chat.id)}
            className="flex items-center p-3 gap-4 cursor-pointer transition-colors"
            style={{
              backgroundColor: activeId === chat.id ? theme.bgTertiary : 'transparent',
              borderBottom: `1px solid ${theme.border}`
            }}
            onMouseEnter={e => { if (activeId !== chat.id) (e.currentTarget.style.backgroundColor = theme.bgSecondary); }}
            onMouseLeave={e => { if (activeId !== chat.id) (e.currentTarget.style.backgroundColor = 'transparent'); }}
          >
            <Avatar name={name} theme={theme} />
            <div className="flex-1 min-w-0">
              <div className="flex justify-between items-center mb-1">
                <h3 className="font-medium truncate" style={{ color: theme.text }}>{name}</h3>
                <span className="text-xs" style={{ color: theme.textSecondary }}>{time}</span>
              </div>
              <div className="flex justify-between items-center">
                <p className="text-sm truncate" style={{ color: theme.textSecondary }}>{preview}</p>
                {chat.unreadCount > 0 && (
                  <span className="ml-2 text-xs rounded-full w-5 h-5 flex items-center justify-center text-white shrink-0"
                    style={{ backgroundColor: theme.accent }}>{chat.unreadCount}</span>
                )}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
