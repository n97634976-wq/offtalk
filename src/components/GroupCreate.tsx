import React, { useState } from 'react';
import { db } from '../lib/db';
import { useLiveQuery } from 'dexie-react-hooks';
import { generateGroupKey } from '../lib/crypto';
import { Theme } from '../lib/theme';
import { t, Lang } from '../lib/i18n';
import { Button, Avatar, Modal } from './ui';
import { X, Check } from 'lucide-react';

export default function GroupCreate({ onClose, onCreated, myId, theme, lang }: {
  onClose: () => void; onCreated: (chatId: string) => void; myId: string; theme: Theme; lang: Lang;
}) {
  const contacts = useLiveQuery(() => db.contacts.toArray());
  const [name, setName] = useState('');
  const [selected, setSelected] = useState<string[]>([]);

  const handleCreate = async () => {
    if (!name.trim() || selected.length === 0) return;
    const groupId = crypto.randomUUID();
    const participants = [myId, ...selected];
    await db.chats.put({
      id: groupId,
      type: 'group',
      name: name.trim(),
      unreadCount: 0,
      createdAt: Date.now(),
      participants,
      groupKey: generateGroupKey(),
      isGroupAdmin: true
    });
    onCreated(groupId);
    onClose();
  };

  const toggle = (id: string) => {
    setSelected(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]);
  };

  return (
    <Modal onClose={onClose} theme={theme}>
      <h2 className="text-lg font-bold mb-4" style={{ color: theme.text }}>{t(lang, 'createGroup')}</h2>
      <input type="text" placeholder={t(lang, 'groupName')} value={name}
        onChange={e => setName(e.target.value)}
        className="w-full rounded-lg p-3 outline-none mb-4"
        style={{ backgroundColor: theme.bgTertiary, color: theme.text }} />
      <p className="text-sm font-medium mb-2" style={{ color: theme.textSecondary }}>{t(lang, 'selectMembers')}</p>
      <div className="max-h-48 overflow-y-auto space-y-1 mb-4">
        {contacts?.filter(c => !c.isBlocked).map(c => (
          <button key={c.id} onClick={() => toggle(c.id)}
            className="w-full flex items-center gap-3 p-2 rounded-lg transition-colors"
            style={{ backgroundColor: selected.includes(c.id) ? theme.accent + '20' : 'transparent' }}>
            <Avatar name={c.displayName} size="sm" theme={theme} />
            <span className="flex-1 text-left text-sm" style={{ color: theme.text }}>{c.displayName}</span>
            {selected.includes(c.id) && <Check size={16} style={{ color: theme.accent }} />}
          </button>
        ))}
        {(!contacts || contacts.length === 0) && (
          <p className="text-sm text-center py-4" style={{ color: theme.textSecondary }}>No contacts yet</p>
        )}
      </div>
      <div className="flex gap-2">
        <Button onClick={onClose} variant="secondary" theme={theme} className="flex-1">{t(lang, 'cancel')}</Button>
        <Button onClick={handleCreate} theme={theme} className="flex-1"
          disabled={!name.trim() || selected.length === 0}>{t(lang, 'create')}</Button>
      </div>
    </Modal>
  );
}
