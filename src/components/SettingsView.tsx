import React, { useState } from 'react';
import { db } from '../lib/db';
import { useLiveQuery } from 'dexie-react-hooks';
import { Theme } from '../lib/theme';
import { t, Lang, langNames } from '../lib/i18n';
import { Button, Avatar } from './ui';
import { ArrowLeft, Users, MessageSquare, AlertTriangle, Moon, Sun, Globe, Download, Upload, Shield } from 'lucide-react';

export default function SettingsView({ user, onBack, theme, lang, onToggleDark, isDark, onChangeLang }: {
  user: any; onBack: () => void; theme: Theme; lang: Lang;
  onToggleDark: () => void; isDark: boolean; onChangeLang: (l: Lang) => void;
}) {
  const [showLang, setShowLang] = useState(false);
  const contacts = useLiveQuery(() => db.contacts.toArray());

  const handleBackup = async () => {
    const allContacts = await db.contacts.toArray();
    const allChats = await db.chats.toArray();
    const allMessages = await db.messages.toArray();
    const allSettings = await db.settings.toArray();
    const backup = JSON.stringify({ contacts: allContacts, chats: allChats, messages: allMessages, settings: allSettings }, null, 2);
    const blob = new Blob([backup], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `offtalk-backup-${Date.now()}.json`; a.click();
    URL.revokeObjectURL(url);
  };

  const handleRestore = () => {
    const input = document.createElement('input');
    input.type = 'file'; input.accept = '.json';
    input.onchange = async (e: any) => {
      const file = e.target.files?.[0]; if (!file) return;
      const text = await file.text();
      try {
        const data = JSON.parse(text);
        if (data.contacts) { await db.contacts.clear(); await db.contacts.bulkAdd(data.contacts); }
        if (data.chats) { await db.chats.clear(); await db.chats.bulkAdd(data.chats); }
        if (data.messages) { await db.messages.clear(); await db.messages.bulkAdd(data.messages); }
        alert(t(lang, 'restoreSuccess'));
      } catch (e) { console.error('Restore failed:', e); }
    };
    input.click();
  };

  const handleBlock = async (contactId: string, block: boolean) => {
    await db.contacts.update(contactId, { isBlocked: block ? 1 : 0 });
  };

  return (
    <div className="p-6 overflow-y-auto">
      <div className="flex items-center gap-4 mb-8">
        <button onClick={onBack} style={{ color: theme.textMuted }}><ArrowLeft size={24} /></button>
        <h2 className="text-xl font-bold" style={{ color: theme.text }}>{t(lang, 'settings')}</h2>
      </div>
      <div className="flex flex-col items-center mb-8">
        <Avatar name={user.displayName} size="lg" theme={theme} />
        <h3 className="text-xl font-bold mt-4" style={{ color: theme.text }}>{user.displayName}</h3>
        <p style={{ color: theme.textSecondary }}>{user.phoneNumber}</p>
      </div>
      <div className="space-y-1">
        {/* Dark Mode */}
        <button onClick={onToggleDark} className="w-full p-4 rounded-lg flex items-center gap-4 hover:opacity-80 transition-opacity"
          style={{ backgroundColor: 'transparent' }}>
          {isDark ? <Moon size={20} style={{ color: theme.textSecondary }} /> : <Sun size={20} style={{ color: theme.textSecondary }} />}
          <div className="flex-1 text-left">
            <p className="font-medium" style={{ color: theme.text }}>{t(lang, 'darkMode')}</p>
            <p className="text-xs" style={{ color: theme.textSecondary }}>{isDark ? 'On' : 'Off'}</p>
          </div>
          <div className={`w-10 h-6 rounded-full relative transition-colors ${isDark ? 'bg-[#00a884]' : 'bg-gray-400'}`}>
            <div className={`w-4 h-4 rounded-full bg-white absolute top-1 transition-transform ${isDark ? 'translate-x-5' : 'translate-x-1'}`} />
          </div>
        </button>
        {/* Language */}
        <div className="relative">
          <button onClick={() => setShowLang(!showLang)} className="w-full p-4 rounded-lg flex items-center gap-4 hover:opacity-80">
            <Globe size={20} style={{ color: theme.textSecondary }} />
            <div className="flex-1 text-left">
              <p className="font-medium" style={{ color: theme.text }}>{t(lang, 'language')}</p>
              <p className="text-xs" style={{ color: theme.textSecondary }}>{langNames[lang]}</p>
            </div>
          </button>
          {showLang && (
            <div className="ml-12 rounded-lg shadow-lg overflow-hidden" style={{ backgroundColor: theme.bgTertiary }}>
              {(Object.keys(langNames) as Lang[]).map(l => (
                <button key={l} onClick={() => { onChangeLang(l); setShowLang(false); }}
                  className="w-full text-left px-4 py-3 text-sm hover:opacity-80 transition-opacity"
                  style={{ color: lang === l ? theme.accent : theme.text, backgroundColor: lang === l ? theme.bgSecondary : 'transparent' }}>
                  {langNames[l]}
                </button>
              ))}
            </div>
          )}
        </div>
        {/* Backup */}
        <button onClick={handleBackup} className="w-full p-4 rounded-lg flex items-center gap-4 hover:opacity-80">
          <Download size={20} style={{ color: theme.textSecondary }} />
          <div className="text-left">
            <p className="font-medium" style={{ color: theme.text }}>{t(lang, 'backup')}</p>
            <p className="text-xs" style={{ color: theme.textSecondary }}>{t(lang, 'backupDesc')}</p>
          </div>
        </button>
        {/* Restore */}
        <button onClick={handleRestore} className="w-full p-4 rounded-lg flex items-center gap-4 hover:opacity-80">
          <Upload size={20} style={{ color: theme.textSecondary }} />
          <div className="text-left">
            <p className="font-medium" style={{ color: theme.text }}>{t(lang, 'restore')}</p>
          </div>
        </button>
        {/* Contacts management */}
        <div className="mt-6">
          <h3 className="text-sm font-bold mb-2 px-4" style={{ color: theme.accent }}>{t(lang, 'contacts')}</h3>
          {contacts?.map(c => (
            <div key={c.id} className="p-3 flex items-center gap-3 rounded-lg" style={{ borderBottom: `1px solid ${theme.border}` }}>
              <Avatar name={c.displayName} size="sm" theme={theme} />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate" style={{ color: theme.text }}>{c.displayName}</p>
                <p className="text-xs" style={{ color: theme.textSecondary }}>{c.id}</p>
              </div>
              <button onClick={() => handleBlock(c.id, !c.isBlocked)}
                className="text-xs px-2 py-1 rounded"
                style={{ backgroundColor: c.isBlocked ? theme.danger : theme.bgTertiary, color: c.isBlocked ? '#fff' : theme.textSecondary }}>
                {c.isBlocked ? t(lang, 'unblockContact') : t(lang, 'blockContact')}
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
