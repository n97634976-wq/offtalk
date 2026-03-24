import React, { useState, useEffect } from 'react';
import { db } from './lib/db';
import { meshManager } from './lib/mesh';
import { getTheme } from './lib/theme';
import { t, Lang } from './lib/i18n';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  MessageSquare, Users, Settings, Plus, Search, AlertTriangle, MapPin, Activity, CheckCheck, UserPlus
} from 'lucide-react';

import Onboarding from './components/Onboarding';
import ChatList from './components/ChatList';
import ChatWindow from './components/ChatWindow';
import PairingView from './components/PairingView';
import SettingsView from './components/SettingsView';
import SOSView from './components/SOSView';
import MapView from './components/MapView';
import MeshMonitorView from './components/MeshMonitorView';
import GroupCreate from './components/GroupCreate';
import VideoCallView from './components/VideoCallView';

type View = 'chats' | 'contacts' | 'settings' | 'pairing' | 'sos' | 'map' | 'monitor';

export default function App() {
  const [user, setUser] = useState<any>(null);
  const [activeChatId, setActiveChatId] = useState<string | null>(null);
  const [view, setView] = useState<View>('chats');
  const [loading, setLoading] = useState(true);
  const [isDark, setIsDark] = useState(true);
  const [lang, setLang] = useState<Lang>('en');
  const [showGroupCreate, setShowGroupCreate] = useState(false);
  const [callState, setCallState] = useState<any>(null);
  const contacts = useLiveQuery(() => db.contacts.toArray());

  const theme = getTheme(isDark);

  useEffect(() => {
    const init = async () => {
      const profile = await db.settings.get('profile');
      if (profile) {
        setUser(profile.value);
        meshManager.init(profile.value.phoneNumber, profile.value.privateKey);
      }
      const prefs = await db.settings.get('preferences');
      if (prefs?.value) {
        if (prefs.value.isDark !== undefined) setIsDark(prefs.value.isDark);
        if (prefs.value.lang) setLang(prefs.value.lang);
      }
      setLoading(false);
    };
    init();
  }, []);

  // Persist preferences
  const toggleDark = async () => {
    const newVal = !isDark;
    setIsDark(newVal);
    await db.settings.put({ key: 'preferences', value: { isDark: newVal, lang } });
  };

  const changeLang = async (l: Lang) => {
    setLang(l);
    await db.settings.put({ key: 'preferences', value: { isDark, lang: l } });
  };

  // Listen for incoming calls
  useEffect(() => {
    if (!user) return;
    meshManager.onCallSignal = (packet: any) => {
      if (!callState && packet.signalData?.type === 'offer') {
        const contact = contacts?.find(c => c.id === packet.sourceId);
        setCallState({
          contactId: packet.sourceId,
          contactName: contact?.displayName || packet.sourceId,
          isVideo: true,
          isIncoming: true
        });
      }
    };
    // Location updates
    meshManager.onLocationUpdate = async (userId: string, lat: number, lng: number) => {
      await db.contacts.update(userId, { lat, lng, lastSeen: Date.now() });
    };
  }, [user, contacts, callState]);

  const handleStartCall = (contactId: string, video: boolean) => {
    const contact = contacts?.find(c => c.id === contactId);
    setCallState({
      contactId,
      contactName: contact?.displayName || contactId,
      isVideo: video,
      isIncoming: false
    });
  };

  if (loading) {
    return (
      <div className="h-screen flex items-center justify-center" style={{ backgroundColor: theme.bg }}>
        <div className="flex flex-col items-center gap-4">
          <div className="w-16 h-16 rounded-full flex items-center justify-center animate-pulse" style={{ backgroundColor: theme.accent }}>
            <MessageSquare size={32} className="text-white" />
          </div>
          <p style={{ color: theme.text }}>Loading OffTalk...</p>
        </div>
      </div>
    );
  }

  if (!user) return <Onboarding onComplete={setUser} theme={theme} lang={lang} />;

  const navItems = [
    { id: 'chats' as View, icon: MessageSquare, label: t(lang, 'chats') },
    { id: 'pairing' as View, icon: UserPlus, label: t(lang, 'addContact') },
    { id: 'map' as View, icon: MapPin, label: t(lang, 'offlineMaps') },
    { id: 'monitor' as View, icon: Activity, label: t(lang, 'meshMonitor') },
    { id: 'sos' as View, icon: AlertTriangle, label: 'SOS' },
    { id: 'settings' as View, icon: Settings, label: t(lang, 'settings') },
  ];

  return (
    <div className="h-screen flex overflow-hidden" style={{ backgroundColor: theme.bg, color: theme.text, fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif' }}>
      {/* Video Call Overlay */}
      {callState && (
        <VideoCallView callState={callState} onEnd={() => setCallState(null)} theme={theme} lang={lang} />
      )}

      {/* Group Create Modal */}
      {showGroupCreate && (
        <GroupCreate onClose={() => setShowGroupCreate(false)}
          onCreated={(id) => { setActiveChatId(id); setView('chats'); }}
          myId={user.phoneNumber} theme={theme} lang={lang} />
      )}

      {/* Sidebar */}
      <div className={`w-full md:w-[400px] flex flex-col ${activeChatId ? 'hidden md:flex' : 'flex'}`}
        style={{ borderRight: `1px solid ${theme.border}` }}>
        {/* Header */}
        <header className="p-3 flex justify-between items-center" style={{ backgroundColor: theme.bgSecondary }}>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full flex items-center justify-center text-white font-bold"
              style={{ backgroundColor: theme.accent }}>{user.displayName.charAt(0)}</div>
            <div>
              <h2 className="text-sm font-bold" style={{ color: theme.text }}>{user.displayName}</h2>
              <p className="text-[10px]" style={{ color: theme.textSecondary }}>{user.phoneNumber}</p>
            </div>
          </div>
          <div className="flex gap-2">
            {navItems.map(item => (
              <button key={item.id} onClick={() => { setView(item.id); setActiveChatId(null); }}
                className="p-2 rounded-lg transition-colors"
                style={{ color: view === item.id ? theme.accent : theme.textMuted,
                  backgroundColor: view === item.id ? theme.accent + '15' : 'transparent' }}
                title={item.label}>
                <item.icon size={18} />
              </button>
            ))}
          </div>
        </header>

        {/* Search + New Group */}
        {view === 'chats' && (
          <div className="p-2 flex gap-2" style={{ backgroundColor: theme.bg }}>
            <div className="flex-1 rounded-lg flex items-center px-3 py-2 gap-3" style={{ backgroundColor: theme.bgSecondary }}>
              <Search size={16} style={{ color: theme.textSecondary }} />
              <input type="text" placeholder={t(lang, 'search')}
                className="bg-transparent border-none outline-none w-full text-sm" style={{ color: theme.text }} />
            </div>
            <button onClick={() => setShowGroupCreate(true)}
              className="p-2 rounded-lg" title={t(lang, 'createGroup')}
              style={{ backgroundColor: theme.bgSecondary, color: theme.textMuted }}>
              <Users size={18} />
            </button>
          </div>
        )}

        {/* View Content */}
        <div className="flex-1 overflow-y-auto">
          {view === 'chats' && <ChatList onSelect={(id: string) => { setActiveChatId(id); }} activeId={activeChatId} theme={theme} lang={lang} />}
          {view === 'pairing' && <PairingView onBack={() => setView('chats')} user={user} theme={theme} lang={lang} />}
          {view === 'settings' && <SettingsView user={user} onBack={() => setView('chats')} theme={theme} lang={lang} onToggleDark={toggleDark} isDark={isDark} onChangeLang={changeLang} />}
          {view === 'sos' && <SOSView user={user} onBack={() => setView('chats')} theme={theme} lang={lang} />}
          {view === 'map' && <MapView onBack={() => setView('chats')} theme={theme} lang={lang} />}
          {view === 'monitor' && <MeshMonitorView onBack={() => setView('chats')} theme={theme} lang={lang} />}
        </div>
      </div>

      {/* Main Chat Area */}
      <div className={`flex-1 flex flex-col relative ${!activeChatId ? 'hidden md:flex' : 'flex'}`}
        style={{ backgroundColor: theme.bgChat }}>
        {activeChatId ? (
          <ChatWindow chatId={activeChatId} onBack={() => setActiveChatId(null)}
            myId={user.phoneNumber} theme={theme} lang={lang} onStartCall={handleStartCall} />
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-center p-8">
            <div className="w-64 h-64 rounded-full flex items-center justify-center mb-8" style={{ backgroundColor: theme.bgSecondary }}>
              <MessageSquare size={120} style={{ color: theme.accent, opacity: 0.2 }} />
            </div>
            <h1 className="text-3xl font-light mb-4" style={{ color: theme.text }}>OffTalk Web</h1>
            <p className="max-w-md" style={{ color: theme.textSecondary }}>{t(lang, 'noServer')}</p>
            <div className="mt-8 flex items-center gap-2 text-sm" style={{ color: theme.textSecondary }}>
              <CheckCheck size={16} style={{ color: theme.accent }} />
              {t(lang, 'e2eEncrypted')}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
