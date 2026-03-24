import { io, Socket } from 'socket.io-client';
import Peer from 'simple-peer';
import { db, Message } from './db';
import { encryptMessage, decryptMessage, deriveSharedSecret } from './crypto';

class MeshManager {
  private socket: Socket;
  private peers: Map<string, Peer.Instance> = new Map();
  private routingTable: Map<string, { nextHop: string, hopCount: number, timestamp: number }> = new Map();
  private processedPacketIds: Set<string> = new Set();
  private pendingQueue: any[] = [];
  private myId: string = '';
  private myPrivateKey: string = '';

  constructor() {
    this.socket = io(window.location.origin);
    this.setupSocket();
    
    // Periodic cleanup of processed packet cache
    setInterval(() => {
      if (this.processedPacketIds.size > 1000) {
        this.processedPacketIds.clear();
      }
    }, 60000);

    // Periodic retry of pending messages
    setInterval(() => this.processPendingQueue(), 10000);
  }

  private setupSocket() {
    this.socket.on('connect', () => {
      console.log('Connected to signaling server');
      if (this.myId) this.socket.emit('join-room', 'global-mesh');
    });

    this.socket.on('signal', ({ signal, from }) => {
      if (this.peers.has(from)) {
        this.peers.get(from)?.signal(signal);
      } else {
        this.initiatePeer(from, false, signal);
      }
    });

    this.socket.on('sos-alert', (data) => {
      console.log('SOS Alert Received:', data);
      // Trigger local notification or UI update
    });
  }

  init(myId: string, privateKey: string) {
    this.myId = myId;
    this.myPrivateKey = privateKey;
    this.socket.emit('join-room', 'global-mesh');
    console.log('MeshManager initialized for', myId);
  }

  private initiatePeer(peerId: string, initiator: boolean, incomingSignal?: any) {
    if (this.peers.has(peerId)) return;

    const peer = new Peer({
      initiator,
      trickle: false,
    });

    peer.on('signal', (signal) => {
      this.socket.emit('signal', { to: peerId, from: this.myId, signal });
    });

    peer.on('connect', () => {
      console.log('P2P Connected with', peerId);
      this.peers.set(peerId, peer);
      this.updateRoutingTable(peerId, peerId, 1);
      this.processPendingQueue();
    });

    peer.on('data', async (data) => {
      try {
        const packet = JSON.parse(data.toString());
        await this.handleIncomingPacket(peerId, packet);
      } catch (e) {
        console.error('Failed to parse incoming data', e);
      }
    });

    peer.on('close', () => {
      this.peers.delete(peerId);
      console.log('P2P Disconnected from', peerId);
    });

    peer.on('error', (err) => {
      console.error('P2P Error with', peerId, err);
      this.peers.delete(peerId);
    });

    if (incomingSignal) {
      peer.signal(incomingSignal);
    }
  }

  private updateRoutingTable(destinationId: string, nextHop: string, hopCount: number) {
    const existing = this.routingTable.get(destinationId);
    if (!existing || existing.hopCount > hopCount) {
      this.routingTable.set(destinationId, { nextHop, hopCount, timestamp: Date.now() });
      console.log(`Routing updated: ${destinationId} via ${nextHop} (${hopCount} hops)`);
    }
  }

  public onCallSignal?: (packet: any) => void;
  public onLocationUpdate?: (userId: string, lat: number, lng: number) => void;

  private async handleIncomingPacket(fromPeerId: string, packet: any) {
    if (this.processedPacketIds.has(packet.id)) return;
    this.processedPacketIds.add(packet.id);

    this.updateRoutingTable(packet.sourceId, fromPeerId, packet.hopCount || 1);

    if (packet.destinationId === this.myId || packet.destinationId === 'broadcast') {
      if (packet.type === 'message') {
        await this.deliverMessage(packet);
      } else if (packet.type === 'call-signal') {
        if (this.onCallSignal) this.onCallSignal(packet);
      }
      if (packet.destinationId === this.myId) return;
    }

    if (packet.ttl > 0) {
      const nextPacket = { ...packet, ttl: packet.ttl - 1, hopCount: (packet.hopCount || 1) + 1 };
      this.forwardPacket(nextPacket);
    }
  }

  private async deliverMessage(packet: any) {
    const chatId = packet.chatId || packet.sourceId;
    let decryptedStr = '';

    try {
      const contact = await db.contacts.get(packet.sourceId);
      if (!contact) return;
      const sharedSecret = deriveSharedSecret(this.myPrivateKey, contact.publicKey);
      decryptedStr = decryptMessage(packet.encryptedPayload, sharedSecret);

      let parsed: any;
      try {
        parsed = JSON.parse(decryptedStr);
      } catch {
        parsed = { text: decryptedStr }; // legacy fallback
      }

      if (parsed.mediaType === 'location') {
        if (this.onLocationUpdate && parsed.mediaData) {
          const loc = JSON.parse(parsed.mediaData);
          this.onLocationUpdate(packet.sourceId, loc.lat, loc.lng);
        }
      }

      // Auto-create group if missing and it's a group message
      let chat = await db.chats.get(chatId);
      if (!chat && parsed.isGroup) {
        chat = {
          id: chatId,
          type: 'group',
          name: parsed.groupName || 'Unknown Group',
          unreadCount: 0,
          createdAt: Date.now(),
          participants: parsed.participants || [this.myId, packet.sourceId]
        };
        await db.chats.put(chat);
      }

      const messageId = packet.originalId || packet.id;
      const existing = await db.messages.get(messageId);
      if (existing) return;

      const message: Message = {
        id: messageId,
        chatId: chatId,
        senderId: packet.sourceId,
        text: parsed.text || '',
        encryptedPayload: packet.encryptedPayload,
        timestamp: packet.timestamp || Date.now(),
        direction: 'received',
        status: 'delivered',
        mediaType: parsed.mediaType,
        mediaData: parsed.mediaData
      };
      
      await db.messages.put(message);
      await db.chats.update(chatId, { lastMessageId: message.id, unreadCount: (chat?.unreadCount || 0) + 1 });
    } catch (e) {
      console.error('Failed to decrypt or process message', e);
    }
  }

  private forwardPacket(packet: any) {
    const route = this.routingTable.get(packet.destinationId);
    if (route) {
      const peer = this.peers.get(route.nextHop);
      if (peer && peer.connected) {
        peer.send(JSON.stringify(packet));
        return true;
      }
    }

    let sentCount = 0;
    this.peers.forEach((peer, id) => {
      if (peer.connected && id !== packet.sourceId) {
        peer.send(JSON.stringify(packet));
        sentCount++;
      }
    });
    return sentCount > 0;
  }

  async sendMessage(chatId: string, text: string, options?: { mediaType?: Message['mediaType'], mediaData?: string }) {
    const chat = await db.chats.get(chatId);
    if (!chat) return;

    const messageId = crypto.randomUUID();
    const payloadObj: any = { text, mediaType: options?.mediaType, mediaData: options?.mediaData };
    
    if (chat.type === 'group') {
      payloadObj.isGroup = true;
      payloadObj.groupName = chat.name;
      payloadObj.participants = chat.participants;
    }

    const message: Message = {
      id: messageId,
      chatId,
      senderId: this.myId,
      text,
      encryptedPayload: '',
      timestamp: Date.now(),
      direction: 'sent',
      status: 'pending',
      mediaType: options?.mediaType,
      mediaData: options?.mediaData
    };

    if (chat.type === 'direct') {
      const contact = await db.contacts.get(chatId);
      if (!contact) return;
      const sharedSecret = deriveSharedSecret(this.myPrivateKey, contact.publicKey);
      const encryptedPayload = encryptMessage(JSON.stringify(payloadObj), sharedSecret);
      message.encryptedPayload = encryptedPayload;

      await db.messages.add(message);
      await db.chats.update(chatId, { lastMessageId: messageId });

      const packet = {
        id: messageId,
        type: 'message',
        chatId,
        sourceId: this.myId,
        destinationId: chatId,
        encryptedPayload,
        timestamp: message.timestamp,
        ttl: 5,
        hopCount: 1
      };

      const delivered = this.forwardPacket(packet);
      if (!delivered) this.pendingQueue.push(packet);
      else await db.messages.update(messageId, { status: 'sent' });

    } else if (chat.type === 'group' && chat.participants) {
      // Just save a placeholder locally since we encrypt differently for each peer
      message.encryptedPayload = 'group-encrypted'; 
      await db.messages.add(message);
      await db.chats.update(chatId, { lastMessageId: messageId });

      let allDelivered = true;
      for (const participantId of chat.participants) {
        if (participantId === this.myId) continue;
        
        const contact = await db.contacts.get(participantId);
        if (!contact) continue;
        
        const sharedSecret = deriveSharedSecret(this.myPrivateKey, contact.publicKey);
        const encryptedPayload = encryptMessage(JSON.stringify(payloadObj), sharedSecret);
        
        const packetId = crypto.randomUUID();
        const packet = {
          id: packetId,
          originalId: messageId,
          type: 'message',
          chatId,
          sourceId: this.myId,
          destinationId: participantId,
          encryptedPayload,
          timestamp: message.timestamp,
          ttl: 5,
          hopCount: 1
        };
        const delivered = this.forwardPacket(packet);
        if (!delivered) {
          this.pendingQueue.push(packet);
          allDelivered = false;
        }
      }
      if (allDelivered) await db.messages.update(messageId, { status: 'sent' });
    }
  }

  sendCallSignal(toId: string, signalData: any) {
    const packet = {
      id: crypto.randomUUID(),
      type: 'call-signal',
      sourceId: this.myId,
      destinationId: toId,
      signalData,
      timestamp: Date.now(),
      ttl: 5,
      hopCount: 1
    };
    this.forwardPacket(packet);
  }

  private async processPendingQueue() {
    if (this.pendingQueue.length === 0) return;
    
    const remaining: any[] = [];
    for (const packet of this.pendingQueue) {
      const delivered = this.forwardPacket(packet);
      if (delivered) {
        await db.messages.update(packet.id, { status: 'sent' });
      } else {
        remaining.push(packet);
      }
    }
    this.pendingQueue = remaining;
  }

  getRoutingTable() {
    return Array.from(this.routingTable.entries()).map(([id, data]) => ({
      id,
      ...data
    }));
  }

  getConnectedPeers() {
    return Array.from(this.peers.keys());
  }

  broadcastSOS(location: { lat: number, lng: number }) {
    this.socket.emit('broadcast-sos', {
      senderId: this.myId,
      location,
      timestamp: Date.now()
    });
  }
}

export const meshManager = new MeshManager();
