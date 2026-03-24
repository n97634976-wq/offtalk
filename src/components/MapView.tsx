import React, { useState, useEffect } from 'react';
import { db } from '../lib/db';
import { useLiveQuery } from 'dexie-react-hooks';
import { Theme } from '../lib/theme';
import { t, Lang } from '../lib/i18n';
import { ArrowLeft, MapPin, Navigation } from 'lucide-react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';

// Fix Leaflet icon
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

function FlyTo({ position }: { position: [number, number] }) {
  const map = useMap();
  useEffect(() => { map.flyTo(position, 13); }, [position]);
  return null;
}

export default function MapView({ onBack, theme, lang }: { onBack: () => void; theme: Theme; lang: Lang }) {
  const [myPos, setMyPos] = useState<[number, number]>([20, 78]);
  const contacts = useLiveQuery(() => db.contacts.toArray());

  useEffect(() => {
    navigator.geolocation.getCurrentPosition((pos) => {
      setMyPos([pos.coords.latitude, pos.coords.longitude]);
    });
  }, []);

  const peerLocations = (contacts || []).filter(c => c.lat && c.lng).map(c => ({
    id: c.id, name: c.displayName, lat: c.lat!, lng: c.lng!
  }));

  return (
    <div className="h-full flex flex-col">
      <div className="p-4 flex items-center gap-4" style={{ backgroundColor: theme.bgSecondary }}>
        <button onClick={onBack} style={{ color: theme.textMuted }}><ArrowLeft size={24} /></button>
        <MapPin size={20} style={{ color: theme.accent }} />
        <h2 className="text-xl font-bold" style={{ color: theme.text }}>{t(lang, 'offlineMaps')}</h2>
        <div className="flex-1"></div>
        <span className="text-xs px-2 py-1 rounded" style={{ backgroundColor: theme.bgTertiary, color: theme.textSecondary }}>
          {peerLocations.length} peers visible
        </span>
      </div>
      <div className="flex-1 z-0 relative">
        <MapContainer {...({ center: myPos, zoom: 5, style: { height: '100%', width: '100%' } } as any)}>
          <TileLayer {...({
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
            url: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          } as any)} />
          <FlyTo position={myPos} />
          <Marker position={myPos}>
            <Popup>📍 You are here (Your Mesh Node)</Popup>
          </Marker>
          {peerLocations.map(p => (
            <Marker key={p.id} position={[p.lat, p.lng]}>
              <Popup>👤 {p.name}</Popup>
            </Marker>
          ))}
        </MapContainer>
        <div className="absolute bottom-4 right-4 z-[1000]">
          <button onClick={() => navigator.geolocation.getCurrentPosition(pos => setMyPos([pos.coords.latitude, pos.coords.longitude]))}
            className="w-12 h-12 rounded-full shadow-xl flex items-center justify-center"
            style={{ backgroundColor: theme.accent }}>
            <Navigation size={20} className="text-white" />
          </button>
        </div>
      </div>
    </div>
  );
}
