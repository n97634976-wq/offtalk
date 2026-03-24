import Dexie, { Table } from 'dexie';

export interface Contact {
  id: string; // phone number
  displayName: string;
  publicKey: string;
  isBlocked: number;
  lastSeen: number;
  createdAt: number;
  lat?: number;
  lng?: number;
}

export interface Chat {
  id: string; // UUID or contact phone number
  type: 'direct' | 'group';
  lastMessageId?: string;
  unreadCount: number;
  createdAt: number;
  name?: string; // for groups
  participants?: string[]; // IDs of members
  groupKey?: string; // encrypted or clear (for demo) group symmetric key
  isGroupAdmin?: boolean;
}

export interface Message {
  id: string;
  chatId: string;
  senderId: string;
  text: string;
  encryptedPayload: string;
  timestamp: number;
  direction: 'sent' | 'received';
  status: 'pending' | 'sent' | 'delivered' | 'read';
  mediaPath?: string;
  mediaType?: 'image' | 'audio' | 'video' | 'file' | 'location' | 'call';
  mediaData?: string; // Base64 depending on size
  expiresAt?: number;
  isEdited?: boolean;
  reactions?: Record<string, string>; // e.g. { '+919876543210': '👍' }
}

export interface Setting {
  key: string;
  value: any;
}

export class OffTalkDB extends Dexie {
  contacts!: Table<Contact>;
  chats!: Table<Chat>;
  messages!: Table<Message>;
  settings!: Table<Setting>;

  constructor() {
    super('OffTalkDB');
    this.version(2).stores({
      contacts: 'id, displayName, lastSeen',
      chats: 'id, type, createdAt',
      messages: 'id, chatId, senderId, timestamp',
      settings: 'key'
    });
  }
}

export const db = new OffTalkDB();
