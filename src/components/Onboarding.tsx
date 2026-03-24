import React, { useState } from 'react';
import { db } from '../lib/db';
import { generateKeyPair } from '../lib/crypto';
import { meshManager } from '../lib/mesh';
import { Theme } from '../lib/theme';
import { t, Lang } from '../lib/i18n';
import { MessageSquare } from 'lucide-react';
import { motion } from 'framer-motion';
import { Button } from './ui';

export default function Onboarding({ onComplete, theme, lang }: { onComplete: (u: any) => void; theme: Theme; lang: Lang }) {
  const [step, setStep] = useState(1);
  const [form, setForm] = useState({ phoneNumber: '', displayName: '', pin: '' });

  const handleFinish = async () => {
    if (!form.phoneNumber || !form.displayName || !form.pin) return;
    const { privateKey, publicKey } = generateKeyPair();
    const profile = { ...form, privateKey, publicKey, createdAt: Date.now() };
    await db.settings.put({ key: 'profile', value: profile });
    meshManager.init(profile.phoneNumber, profile.privateKey);
    onComplete(profile);
  };

  return (
    <div className="h-screen flex items-center justify-center p-4" style={{ backgroundColor: theme.bg }}>
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}
        className="p-8 rounded-2xl w-full max-w-md shadow-2xl" style={{ backgroundColor: theme.bgSecondary }}>
        <div className="text-center mb-8">
          <div className="w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-4" style={{ backgroundColor: theme.accent }}>
            <MessageSquare size={40} className="text-white" />
          </div>
          <h1 className="text-2xl font-bold" style={{ color: theme.text }}>{t(lang, 'welcome')}</h1>
          <p className="mt-2" style={{ color: theme.textSecondary }}>{t(lang, 'secureMsg')}</p>
        </div>
        {step === 1 && (
          <div className="space-y-4">
            <div>
              <label className="block text-sm mb-1" style={{ color: theme.textSecondary }}>{t(lang, 'phoneNumber')}</label>
              <input type="text" value={form.phoneNumber}
                onChange={e => setForm({ ...form, phoneNumber: e.target.value })}
                className="w-full rounded-lg p-3 outline-none border-none"
                style={{ backgroundColor: theme.bgTertiary, color: theme.text }}
                placeholder="+91 98765 43210" />
            </div>
            <Button onClick={() => form.phoneNumber && setStep(2)} theme={theme} className="w-full">{t(lang, 'next')}</Button>
          </div>
        )}
        {step === 2 && (
          <div className="space-y-4">
            <div>
              <label className="block text-sm mb-1" style={{ color: theme.textSecondary }}>{t(lang, 'displayName')}</label>
              <input type="text" value={form.displayName}
                onChange={e => setForm({ ...form, displayName: e.target.value })}
                className="w-full rounded-lg p-3 outline-none border-none"
                style={{ backgroundColor: theme.bgTertiary, color: theme.text }}
                placeholder="John Doe" />
            </div>
            <div>
              <label className="block text-sm mb-1" style={{ color: theme.textSecondary }}>{t(lang, 'encryptionPin')}</label>
              <input type="password" value={form.pin}
                onChange={e => setForm({ ...form, pin: e.target.value })}
                className="w-full rounded-lg p-3 outline-none border-none"
                style={{ backgroundColor: theme.bgTertiary, color: theme.text }}
                placeholder="••••••" />
            </div>
            <div className="flex gap-2">
              <Button onClick={() => setStep(1)} variant="secondary" theme={theme} className="flex-1">{t(lang, 'back')}</Button>
              <Button onClick={handleFinish} theme={theme} className="flex-1">{t(lang, 'getStarted')}</Button>
            </div>
          </div>
        )}
      </motion.div>
    </div>
  );
}
