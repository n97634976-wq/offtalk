import React, { useState, useEffect, useRef } from 'react';
import { meshManager } from '../lib/mesh';
import { Theme } from '../lib/theme';
import { t, Lang } from '../lib/i18n';
import { Button } from './ui';
import { Phone, PhoneOff, Video, VideoOff, Mic, MicOff, X } from 'lucide-react';
import { motion } from 'framer-motion';

interface CallState {
  contactId: string;
  contactName: string;
  isVideo: boolean;
  isIncoming: boolean;
}

export default function VideoCallView({ callState, onEnd, theme, lang }: {
  callState: CallState; onEnd: () => void; theme: Theme; lang: Lang;
}) {
  const [accepted, setAccepted] = useState(!callState.isIncoming);
  const [muted, setMuted] = useState(false);
  const [videoOff, setVideoOff] = useState(false);
  const [callDuration, setCallDuration] = useState(0);
  const localVideoRef = useRef<HTMLVideoElement>(null);
  const remoteVideoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const peerRef = useRef<RTCPeerConnection | null>(null);

  useEffect(() => {
    if (!accepted) return;
    let interval: any;
    const startCall = async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          audio: true,
          video: callState.isVideo
        });
        streamRef.current = stream;
        if (localVideoRef.current) localVideoRef.current.srcObject = stream;

        // Create peer connection
        const pc = new RTCPeerConnection({ iceServers: [{ urls: 'stun:stun.l.google.com:19302' }] });
        peerRef.current = pc;
        stream.getTracks().forEach(track => pc.addTrack(track, stream));
        pc.ontrack = (e) => {
          if (remoteVideoRef.current && e.streams[0]) remoteVideoRef.current.srcObject = e.streams[0];
        };
        pc.onicecandidate = (e) => {
          if (e.candidate) {
            meshManager.sendCallSignal(callState.contactId, { type: 'ice', candidate: e.candidate });
          }
        };
        // Listen for incoming signals
        meshManager.onCallSignal = async (packet) => {
          if (packet.sourceId === callState.contactId) {
            const sig = packet.signalData;
            if (sig.type === 'offer') {
              await pc.setRemoteDescription(new RTCSessionDescription(sig.sdp));
              const answer = await pc.createAnswer();
              await pc.setLocalDescription(answer);
              meshManager.sendCallSignal(callState.contactId, { type: 'answer', sdp: answer });
            } else if (sig.type === 'answer') {
              await pc.setRemoteDescription(new RTCSessionDescription(sig.sdp));
            } else if (sig.type === 'ice' && sig.candidate) {
              await pc.addIceCandidate(new RTCIceCandidate(sig.candidate));
            }
          }
        };
        // If not incoming, create offer
        if (!callState.isIncoming) {
          const offer = await pc.createOffer();
          await pc.setLocalDescription(offer);
          meshManager.sendCallSignal(callState.contactId, { type: 'offer', sdp: offer });
        }
        // Timer
        interval = setInterval(() => setCallDuration(prev => prev + 1), 1000);
      } catch (e) { console.error('Call failed:', e); }
    };
    startCall();
    return () => {
      clearInterval(interval);
      streamRef.current?.getTracks().forEach(t => t.stop());
      peerRef.current?.close();
      meshManager.onCallSignal = undefined;
    };
  }, [accepted]);

  const toggleMute = () => {
    streamRef.current?.getAudioTracks().forEach(t => { t.enabled = !t.enabled; });
    setMuted(!muted);
  };

  const toggleVideo = () => {
    streamRef.current?.getVideoTracks().forEach(t => { t.enabled = !t.enabled; });
    setVideoOff(!videoOff);
  };

  const endCall = () => {
    streamRef.current?.getTracks().forEach(t => t.stop());
    peerRef.current?.close();
    onEnd();
  };

  const formatTime = (s: number) => `${Math.floor(s / 60).toString().padStart(2, '0')}:${(s % 60).toString().padStart(2, '0')}`;

  // Incoming call not yet accepted
  if (!accepted) {
    return (
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
        className="fixed inset-0 z-50 flex flex-col items-center justify-center bg-black/90">
        <div className="w-24 h-24 rounded-full flex items-center justify-center mb-6 text-white text-3xl font-bold"
          style={{ backgroundColor: theme.accent }}>{callState.contactName.charAt(0)}</div>
        <h2 className="text-2xl font-bold text-white mb-2">{callState.contactName}</h2>
        <p className="text-gray-400 mb-12">{t(lang, 'incomingCall')}</p>
        <div className="flex gap-12">
          <button onClick={endCall}
            className="w-16 h-16 rounded-full flex items-center justify-center" style={{ backgroundColor: theme.danger }}>
            <PhoneOff size={28} className="text-white" />
          </button>
          <button onClick={() => setAccepted(true)}
            className="w-16 h-16 rounded-full flex items-center justify-center" style={{ backgroundColor: theme.accent }}>
            <Phone size={28} className="text-white" />
          </button>
        </div>
      </motion.div>
    );
  }

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
      className="fixed inset-0 z-50 flex flex-col bg-black">
      {/* Remote video */}
      <div className="flex-1 relative">
        {callState.isVideo ? (
          <video ref={remoteVideoRef} autoPlay playsInline className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full flex flex-col items-center justify-center">
            <div className="w-24 h-24 rounded-full flex items-center justify-center mb-4 text-white text-3xl font-bold"
              style={{ backgroundColor: theme.accent }}>{callState.contactName.charAt(0)}</div>
            <h2 className="text-2xl font-bold text-white">{callState.contactName}</h2>
            <p className="text-gray-400 mt-2">{formatTime(callDuration)}</p>
          </div>
        )}
        {/* Local video PiP */}
        {callState.isVideo && (
          <div className="absolute top-4 right-4 w-32 h-44 rounded-xl overflow-hidden shadow-xl border-2 border-white/20">
            <video ref={localVideoRef} autoPlay playsInline muted className="w-full h-full object-cover" />
          </div>
        )}
        {callState.isVideo && (
          <div className="absolute top-4 left-4 text-white text-sm bg-black/50 px-3 py-1 rounded-full">{formatTime(callDuration)}</div>
        )}
      </div>
      {/* Controls */}
      <div className="p-8 flex justify-center gap-6">
        <button onClick={toggleMute}
          className="w-14 h-14 rounded-full flex items-center justify-center"
          style={{ backgroundColor: muted ? '#fff' : 'rgba(255,255,255,0.2)' }}>
          {muted ? <MicOff size={24} color="#000" /> : <Mic size={24} color="#fff" />}
        </button>
        {callState.isVideo && (
          <button onClick={toggleVideo}
            className="w-14 h-14 rounded-full flex items-center justify-center"
            style={{ backgroundColor: videoOff ? '#fff' : 'rgba(255,255,255,0.2)' }}>
            {videoOff ? <VideoOff size={24} color="#000" /> : <Video size={24} color="#fff" />}
          </button>
        )}
        <button onClick={endCall}
          className="w-14 h-14 rounded-full flex items-center justify-center" style={{ backgroundColor: theme.danger }}>
          <PhoneOff size={24} color="#fff" />
        </button>
      </div>
    </motion.div>
  );
}
