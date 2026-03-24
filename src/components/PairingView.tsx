import React, { useState, useEffect } from 'react';
import { db } from '../lib/db';
import { Theme } from '../lib/theme';
import { t, Lang } from '../lib/i18n';
import { Button, Avatar } from './ui';
import { ArrowLeft, QrCode } from 'lucide-react';
import { QRCodeSVG } from 'qrcode.react';
import { Html5QrcodeScanner } from 'html5-qrcode';

export default function PairingView({ onBack, user, theme, lang }: { onBack: () => void; user: any; theme: Theme; lang: Lang }) {
  const [mode, setMode] = useState<'qr' | 'scan' | 'manual'>('qr');
  const [manualForm, setManualForm] = useState({ phone: '', publicKey: '', name: '' });

  const qrData = JSON.stringify({ phoneNumber: user.phoneNumber, displayName: user.displayName, publicKey: user.publicKey });

  useEffect(() => {
    let scanner: Html5QrcodeScanner | null = null;
    if (mode === 'scan') {
      scanner = new Html5QrcodeScanner("reader", { fps: 10, qrbox: 250 }, false);
      scanner.render(async (decodedText) => {
        try {
          const data = JSON.parse(decodedText);
          if (data.phoneNumber && data.publicKey) {
            await db.contacts.put({ id: data.phoneNumber, displayName: data.displayName || data.phoneNumber, publicKey: data.publicKey, isBlocked: 0, lastSeen: Date.now(), createdAt: Date.now() });
            await db.chats.put({ id: data.phoneNumber, type: 'direct', unreadCount: 0, createdAt: Date.now() });
            setMode('qr');
          }
        } catch (e) { console.error("Invalid QR", e); }
      }, () => {});
    }
    return () => { if (scanner) scanner.clear().catch(() => {}); };
  }, [mode]);

  const handleManualAdd = async () => {
    if (!manualForm.phone) return;
    await db.contacts.put({ id: manualForm.phone, displayName: manualForm.name || manualForm.phone, publicKey: manualForm.publicKey || 'manual-key', isBlocked: 0, lastSeen: Date.now(), createdAt: Date.now() });
    await db.chats.put({ id: manualForm.phone, type: 'direct', unreadCount: 0, createdAt: Date.now() });
    setManualForm({ phone: '', publicKey: '', name: '' });
    setMode('qr');
  };

  return (
    <div className="p-6 flex flex-col items-center gap-6">
      <div className="w-full flex items-center gap-4 mb-2">
        <button onClick={onBack} style={{ color: theme.textMuted }}><ArrowLeft size={24} /></button>
        <h2 className="text-xl font-bold" style={{ color: theme.text }}>{t(lang, 'addContact')}</h2>
      </div>
      <div className="flex gap-2 w-full">
        {['qr', 'scan', 'manual'].map(m => (
          <button key={m} onClick={() => setMode(m as any)}
            className="flex-1 py-2 rounded-lg text-sm font-medium transition-colors"
            style={{ backgroundColor: mode === m ? theme.accent : theme.bgTertiary, color: mode === m ? '#fff' : theme.textSecondary }}>
            {m === 'qr' ? t(lang, 'showQR') : m === 'scan' ? t(lang, 'scanQR') : t(lang, 'manualAdd')}
          </button>
        ))}
      </div>
      {mode === 'qr' && (
        <>
          <div className="bg-white p-4 rounded-xl shadow-lg"><QRCodeSVG value={qrData} size={200} /></div>
          <p className="text-sm text-center" style={{ color: theme.textSecondary }}>Show this QR code to your friend to pair devices</p>
        </>
      )}
      {mode === 'scan' && <div className="w-full"><div id="reader" className="w-full rounded-xl overflow-hidden bg-black"></div></div>}
      {mode === 'manual' && (
        <div className="w-full space-y-3">
          <input type="text" placeholder={t(lang, 'phoneNumber')} value={manualForm.phone}
            onChange={e => setManualForm({ ...manualForm, phone: e.target.value })}
            className="w-full rounded-lg p-3 outline-none" style={{ backgroundColor: theme.bgTertiary, color: theme.text }} />
          <input type="text" placeholder={t(lang, 'displayName')} value={manualForm.name}
            onChange={e => setManualForm({ ...manualForm, name: e.target.value })}
            className="w-full rounded-lg p-3 outline-none" style={{ backgroundColor: theme.bgTertiary, color: theme.text }} />
          <input type="text" placeholder={t(lang, 'publicKey')} value={manualForm.publicKey}
            onChange={e => setManualForm({ ...manualForm, publicKey: e.target.value })}
            className="w-full rounded-lg p-3 outline-none" style={{ backgroundColor: theme.bgTertiary, color: theme.text }} />
          <Button onClick={handleManualAdd} theme={theme} className="w-full">{t(lang, 'add')}</Button>
        </div>
      )}
    </div>
  );
}
