import React, { useState, useEffect } from 'react';
import { meshManager } from '../lib/mesh';
import { Theme } from '../lib/theme';
import { t, Lang } from '../lib/i18n';
import { ArrowLeft, AlertTriangle } from 'lucide-react';
import { motion } from 'framer-motion';

export default function SOSView({ user, onBack, theme, lang }: { user: any; onBack: () => void; theme: Theme; lang: Lang }) {
  const [active, setActive] = useState(false);

  const handleSOS = () => {
    setActive(true);
    navigator.geolocation.getCurrentPosition((pos) => {
      meshManager.broadcastSOS({ lat: pos.coords.latitude, lng: pos.coords.longitude });
    }, () => {
      meshManager.broadcastSOS({ lat: 0, lng: 0 });
    });
    setTimeout(() => setActive(false), 5000);
  };

  return (
    <div className="p-6 flex flex-col items-center">
      <div className="w-full flex items-center gap-4 mb-12">
        <button onClick={onBack} style={{ color: theme.textMuted }}><ArrowLeft size={24} /></button>
        <h2 className="text-xl font-bold" style={{ color: theme.text }}>{t(lang, 'sosMode')}</h2>
      </div>
      <motion.button
        animate={active ? { scale: [1, 1.2, 1] } : {}}
        transition={{ repeat: Infinity, duration: 1 }}
        onClick={handleSOS}
        className="w-48 h-48 rounded-full flex flex-col items-center justify-center gap-4 shadow-2xl transition-colors"
        style={{
          backgroundColor: active ? theme.danger : theme.bgSecondary,
          border: active ? 'none' : `4px solid ${theme.danger}`
        }}>
        <AlertTriangle size={64} style={{ color: active ? '#fff' : theme.danger }} />
        <span className="font-bold text-xl" style={{ color: active ? '#fff' : theme.danger }}>SOS</span>
      </motion.button>
      <div className="mt-12 text-center">
        <p className="mb-4" style={{ color: theme.textSecondary }}>{t(lang, 'sosDesc')}</p>
        {active && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
            className="font-bold flex items-center gap-2 justify-center" style={{ color: theme.danger }}>
            <div className="w-2 h-2 rounded-full animate-ping" style={{ backgroundColor: theme.danger }} />
            {t(lang, 'sosBroadcast')}
          </motion.div>
        )}
      </div>
    </div>
  );
}
