import React, { useState, useEffect } from 'react';
import { meshManager } from '../lib/mesh';
import { Theme } from '../lib/theme';
import { t, Lang } from '../lib/i18n';
import { ArrowLeft, Users, MapPin, Activity, Wifi, Radio, BarChart3 } from 'lucide-react';

export default function MeshMonitorView({ onBack, theme, lang }: { onBack: () => void; theme: Theme; lang: Lang }) {
  const [peers, setPeers] = useState<string[]>([]);
  const [routes, setRoutes] = useState<any[]>([]);

  useEffect(() => {
    const interval = setInterval(() => {
      setPeers(meshManager.getConnectedPeers());
      setRoutes(meshManager.getRoutingTable());
    }, 2000);
    setPeers(meshManager.getConnectedPeers());
    setRoutes(meshManager.getRoutingTable());
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="p-6 overflow-y-auto">
      <div className="flex items-center gap-4 mb-6">
        <button onClick={onBack} style={{ color: theme.textMuted }}><ArrowLeft size={24} /></button>
        <Activity size={20} style={{ color: theme.accent }} />
        <h2 className="text-xl font-bold" style={{ color: theme.text }}>{t(lang, 'meshMonitor')}</h2>
      </div>
      {/* Stats cards */}
      <div className="grid grid-cols-2 gap-3 mb-6">
        {[
          { icon: <Wifi size={20} />, label: t(lang, 'meshNodes'), value: peers.length, color: theme.accent },
          { icon: <Radio size={20} />, label: t(lang, 'routingTable'), value: routes.length, color: '#53bdeb' },
        ].map((stat, i) => (
          <div key={i} className="p-4 rounded-xl" style={{ backgroundColor: theme.bgSecondary }}>
            <div className="flex items-center gap-2 mb-2" style={{ color: stat.color }}>{stat.icon}<span className="text-xs font-medium">{stat.label}</span></div>
            <p className="text-3xl font-bold" style={{ color: theme.text }}>{stat.value}</p>
          </div>
        ))}
      </div>
      {/* Mesh visualization */}
      <div className="rounded-xl p-4 mb-6" style={{ backgroundColor: theme.bgSecondary }}>
        <h3 className="font-bold mb-3 flex items-center gap-2" style={{ color: theme.accent }}>
          <BarChart3 size={16} /> Network Topology
        </h3>
        <div className="flex items-center justify-center min-h-[120px] relative">
          {/* Center node (you) */}
          <div className="w-14 h-14 rounded-full flex items-center justify-center text-white text-xs font-bold z-10 shadow-lg"
            style={{ backgroundColor: theme.accent }}>YOU</div>
          {/* Peer nodes */}
          {peers.map((peer, i) => {
            const angle = (i / Math.max(peers.length, 1)) * 2 * Math.PI - Math.PI / 2;
            const r = 70;
            const x = Math.cos(angle) * r;
            const y = Math.sin(angle) * r;
            return (
              <React.Fragment key={peer}>
                <div className="w-[2px] absolute z-0" style={{
                  backgroundColor: theme.accent + '40',
                  height: `${r}px`,
                  transformOrigin: 'bottom center',
                  transform: `rotate(${angle + Math.PI/2}rad)`,
                  left: '50%', top: '50%', marginLeft: '-1px', marginTop: `-${r}px`
                }} />
                <div className="w-10 h-10 rounded-full flex items-center justify-center text-[9px] font-mono absolute z-10 shadow"
                  style={{
                    backgroundColor: theme.bgTertiary, color: theme.text,
                    transform: `translate(${x}px, ${y}px)`
                  }}>
                  {peer.slice(-4)}
                </div>
              </React.Fragment>
            );
          })}
          {peers.length === 0 && <p className="text-sm" style={{ color: theme.textSecondary, position: 'absolute', top: 70 }}>{t(lang, 'noNeighbors')}</p>}
        </div>
      </div>
      {/* Neighbors list */}
      <section className="mb-6">
        <h3 className="font-bold mb-3 flex items-center gap-2" style={{ color: theme.accent }}>
          <Users size={16} /> {t(lang, 'connectedNeighbors')} ({peers.length})
        </h3>
        <div className="space-y-2">
          {peers.length === 0 ? (
            <p className="text-sm" style={{ color: theme.textSecondary }}>{t(lang, 'noNeighbors')}</p>
          ) : peers.map(peerId => (
            <div key={peerId} className="p-3 rounded-lg flex justify-between items-center" style={{ backgroundColor: theme.bgSecondary }}>
              <span className="text-sm font-mono" style={{ color: theme.text }}>{peerId}</span>
              <span className="text-xs px-2 py-1 rounded text-white" style={{ backgroundColor: theme.accent }}>{t(lang, 'direct')}</span>
            </div>
          ))}
        </div>
      </section>
      {/* Routing table */}
      <section>
        <h3 className="font-bold mb-3 flex items-center gap-2" style={{ color: '#53bdeb' }}>
          <MapPin size={16} /> {t(lang, 'routingTable')} ({routes.length})
        </h3>
        <div className="space-y-2">
          {routes.length === 0 ? (
            <p className="text-sm" style={{ color: theme.textSecondary }}>{t(lang, 'routingEmpty')}</p>
          ) : routes.map(route => (
            <div key={route.id} className="p-3 rounded-lg" style={{ backgroundColor: theme.bgSecondary }}>
              <div className="flex justify-between items-center mb-1">
                <span className="text-sm font-mono truncate max-w-[200px]" style={{ color: theme.text }}>{route.id}</span>
                <span className="text-xs" style={{ color: theme.textSecondary }}>{route.hopCount} {t(lang, 'hops')}</span>
              </div>
              <div className="text-[10px]" style={{ color: theme.textSecondary }}>
                {t(lang, 'nextHop')}: <span className="font-mono">{route.nextHop}</span>
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
