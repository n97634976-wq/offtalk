<h1 align="center">
  <img src="assets/icon.png" width="120" alt="OffTalk Logo">
  <br>
  OffTalk (formerly MeshTalk)
</h1>

<p align="center">
  <strong>The 100% Offline-First, Serverless, Peer-to-Peer Messaging App.</strong>
</p>

---

## 📥 Download the App (Latest APK)

You do not need the Google Play Store to install OffTalk!

👉 **[Download OffTalk v1.0.0-beta APK](../../releases/latest)** 👈

**How to Install:**
1. Click the download link above and save the `.apk` file to your Android phone.
2. Open your File Manager and tap the downloaded file.
3. If prompted, click **Settings** and allow **"Install from unknown sources"**.
4. Click **Install** and you're ready to start communicating entirely offline.

---

# MeshTalk – Complete App Behavior After Full Development

## 1. Overview

MeshTalk (now refined as OffTalk) is a native mobile app that allows you to communicate **without any internet or cellular network**. It works by using your phone’s Bluetooth and Wi‑Fi Direct to create a local mesh with nearby devices. If you have internet access, it also joins a global peer‑to‑peer network (libp2p) so you can reach people far away. All messages are end‑to‑end encrypted, stored encrypted on your device, and there are **no central servers** – every phone acts as a server.

The app looks and feels like WhatsApp (chat list, message bubbles, delivery ticks) but works entirely offline.

---

## 2. Getting Started (Onboarding)

When you open MeshTalk for the first time:

1. **Permissions:** The app asks for permissions needed to work offline:  
   - **Location** (required for Bluetooth scanning on Android)  
   - **Bluetooth** (to discover and connect to other phones)  
   - **Storage** (to save messages, media, and backups)  
   - **Camera** (to scan QR codes)  
   - **Microphone** (for voice notes and calls)  
   - **Notifications** (to alert you of new messages)

2. **SIM Detection:** The app reads your phone number from the SIM card. This number becomes your identity in the app (it is never sent to any server). If the SIM number cannot be read, you can enter it manually.  

3. **PIN Creation:** You choose a 4‑6 digit PIN. This PIN is used to **encrypt all data stored on your phone** (messages, contacts, keys). Without the PIN, no one can read your data, even if they have your phone.  

4. **Profile Setup:** You can optionally set a display name (how others see you). Your public encryption key is generated and stored securely, protected by your PIN.

5. **Main Screen:** After setup, you see an empty chat list. From here you can add contacts, start chats, or adjust settings.

---

## 3. Adding Contacts (Pairing)

Because there is no central server, you must **manually pair** with people you want to talk to. This is done via QR codes:

- **To add a contact:** Tap the “+” in the contacts screen, then scan the other person’s QR code. The QR code contains their phone number and public key.  
- **To share your own QR code:** Go to your profile in settings, where a QR code is displayed. The other person scans it.  
- **NFC Bump:** Simply tap the back of your phones together to instantly trade encryption keys offline!

When both devices have scanned each other’s QR codes (or one scans the other’s code), they automatically establish an **end‑to‑end encrypted session** using the **Themis Secure Session** protocol (ECDH + forward secrecy). The session is stored locally, and you can now chat even if you never meet again.

**Note:** If you are in Bluetooth range during pairing, the session is established immediately. If not, the public key is stored and the session will be created when you first connect.

---

## 4. Messaging – Local (Bluetooth / Wi‑Fi Direct)

Once you have a contact, you can send them messages, images, voice notes, or files. Simply tap the new 😊 emoji icon next to the chat bar to express yourself securely without internet!

### 4.1 How It Works (Direct Connection)

- When you open a chat, the app automatically tries to **discover the contact via Bluetooth LE** (Low Energy).  
- If the contact is nearby (within ~10–30 meters), a **Bluetooth Classic (RFCOMM)** connection is established. This connection is reliable and can carry encrypted messages, delivery receipts, and small media.  
- For larger files (photos, videos, documents), the app may switch to **Wi‑Fi Direct** (Android) or **Multipeer Connectivity** (iOS) for higher speed and longer range (~50–200 meters).  

Messages appear in the chat with a **single tick** when sent, a **double tick** when delivered to the recipient’s device, and **double tick blue** when read.

### 4.2 Mesh Routing (Multi‑hop)

If the recipient is **not in direct Bluetooth range**, but there are other MeshTalk users in between, the message can **hop** through them:

- Each phone acts as a router. When you send a message, it is wrapped in a **packet** with a unique ID, your ID, the recipient’s ID, and a **time‑to‑live (TTL)** (default 5 hops).  
- The packet is broadcast to all nearby devices.  
- If a device receives a packet not destined for itself, it checks if it has seen this packet before (duplicate elimination). If not, it looks up the best next hop in its **routing table** (learned from previous successful deliveries).  
- If a route exists, it forwards the packet to that neighbor. If not, it broadcasts the packet (with TTL‑‑) to all its neighbors.  
- The packet continues hopping until it reaches the destination or TTL expires.

**Store‑and‑forward:** If the recipient is offline (not in the mesh), the packet is stored locally in a **persistent queue**. When the recipient becomes reachable (e.g., enters Bluetooth range or connects to the internet), the queued messages are delivered automatically.

---

## 5. Messaging – Global (Internet P2P)

When your phone has an internet connection (Wi‑Fi or mobile data), MeshTalk automatically activates its **global peer‑to‑peer layer** using **libp2p**. This allows you to communicate with contacts anywhere in the world, without central servers.

### 5.1 Discovery and Connection

- Each device gets a **peer ID** derived from its public key.  
- It joins a **Distributed Hash Table (DHT)** (Kademlia) that maps phone numbers (hashed) to network addresses.  
- When you try to message a contact who is not in Bluetooth range, the app queries the DHT for their current IP address (or a relay address).  
- A direct encrypted connection is established using **TCP** or **QUIC** (with Noise protocol).  
- If both devices are behind strict NAT (carrier‑grade NAT), the connection may go through a **circuit relay** – another peer with a public IP that forwards traffic for them. Any volunteer device can act as a relay.

### 5.2 Hybrid Gateway

If you are in a local mesh (no internet) and some of your neighbors have internet, they act as **gateways**:

- The gateway subscribes to DHT topics for the phone numbers of people in your local mesh.  
- When you send a message to someone far away, it hops to the gateway via Bluetooth, which then uploads the message to the DHT under the recipient’s key.  
- A gateway near the recipient downloads the message and injects it into their local mesh.

This way, the app seamlessly bridges local and global networks, giving you the best of both worlds.

---

## 6. Group Chats

Group chats are fully encrypted and decentralized.

- **Creating a group:** You select a name and add contacts from your list. The group creator generates a **symmetric AES‑256 group key**.  
- **Adding members:** The group key is encrypted with each new member’s public key (Themis Secure Cell) and sent to them via the existing encrypted channel.  
- **Group messaging:** Each message is encrypted with the current group key.  
- **Key rotation:** When a member is added or removed, a new group key is generated and sent to all remaining members. This ensures that former members cannot read future messages.

Group admins can add/remove members, promote other admins, and change group info.

---

## 7. Voice & Video Calls

You can make one‑to‑one voice and video calls over Wi‑Fi Direct (local) or libp2p (internet). The call is encrypted (SRTP) and uses **WebRTC**:

- The app exchanges **SDP** (session description) and **ICE candidates** via the existing encrypted messaging channel.  
- It then establishes a direct peer‑to‑peer connection using the best available transport.  
- Calls are high‑quality, adaptive to network conditions.

---

## 8. Location Sharing & SOS

### 8.1 Live Location
You can share your real‑time location with a contact or group for a chosen duration (e.g., 15 minutes, 1 hour). The location is displayed on an **offline map** (OpenStreetMap tiles that can be pre‑downloaded). The map works even without internet.

### 8.2 SOS Mode
A large red button (or shortcut) sends an **emergency alert** to **all nearby devices** (even those not in your contacts). The alert includes your current location and a message. Recipients see a prominent notification with the location on a map and can respond or help.

---

## 9. Security & Privacy

- **End‑to‑end encryption:** All 1‑1 chats use Themis Secure Session (forward secrecy). Group chats use a rotating symmetric key.  
- **Local storage:** All messages, contacts, and keys are encrypted with SQLCipher, keyed by your PIN (PBKDF2). Even if someone accesses your phone’s storage, they cannot read the data without the PIN.  
- **No metadata collection:** There is no central server; your IP address, contact lists, and communication patterns are never logged.  
- **Screen security:** You can enable screenshot blocking (Android) and hide notification content.  
- **Secure backup:** You can export an encrypted backup of all data to your device storage or SD card. To restore, you need the same PIN.
- **NO API KEYS!** Because OffTalk is 100% serverless, there are ZERO API keys left in the code. You will never be charged for sending a message.

---

## 10. Advanced Features

- **Message expiration:** Set a message to self‑destruct after a certain time (e.g., 1 hour, 1 day).  
- **Message reactions:** React to messages with emojis (like, heart, etc) using the newly added Offline Emoji Keyboard.  
- **Message editing:** Edit a sent message within 10 minutes; the edited version syncs to the recipient.  
- **Scheduled messages:** Compose a message now and set a future delivery time (e.g., send when the recipient comes online).  
- **File sharing:** Send any file (PDF, APK, etc.) – automatically chunked, with resume support.  
- **Mesh health monitor:** A visual dashboard shows nearby nodes, hop counts, signal strength, and the path your messages take.  
- **Dark mode and themes:** Choose a light or dark theme, and optionally custom accent colors.  
- **Multi‑language:** UI fully translated to English, Hindi, Malayalam, Tamil, and Bengali (easily extensible).  
- **Energy‑saving mode:** Reduces scanning frequency and disables relaying to save battery.  
- **Public channels:** Anyone can create a broadcast‑only channel for community announcements (e.g., disaster alerts). Users can subscribe to channels via QR code or link.

---

## 11. Platform Differences

| Feature | Android | iOS |
|---------|--------|-----|
| Bluetooth | Full BLE + RFCOMM support | BLE only; RFCOMM not available. Multipeer Connectivity for peer‑to‑peer data. |
| Wi‑Fi Direct | Supported for high‑bandwidth | Not available; uses Multipeer Connectivity instead. |
| Background operation | Can run a foreground service for relaying | Limited; app can only relay when in foreground. Background BLE scanning possible but restricted. |
| File sharing | Wi‑Fi Direct for fast transfers | Multipeer Connectivity (slower, but works). |
| Calls | Full WebRTC support | Full WebRTC support (with native plugins). |
| SOS mode | Works via foreground service | Works only when app is in foreground. |

**iOS users** can still use all messaging, calls, and location features, but they cannot act as permanent relays in the background. They can, however, initiate communication and receive messages when the app is open.

---

## 12. Limitations & Expected Behavior

- **Mesh range:** Bluetooth range is typically 10–30 meters indoors, up to 100 meters outdoors. Wi‑Fi Direct extends to ~200 meters. Multi‑hop can extend coverage indefinitely if there are enough users in between.  
- **Delivery guarantees:** Messages are stored locally and retried automatically. If a recipient is offline for a long time (e.g., days), messages remain queued and will be delivered when they reappear.  
- **Battery impact:** Continuous scanning and relaying consume battery. The energy‑saving mode reduces this; you can also manually disable relaying.  
- **Data usage:** When using internet P2P, data is used for messages and calls. No data is used when offline.  
- **Initial pairing:** You must physically meet or share QR codes to add contacts. This ensures that you only communicate with people you trust.  
- **No contact discovery:** The app does not automatically find contacts by phone number (like WhatsApp) because that would require a central server. You add contacts only by scanning their QR code.

---

## 13. Use Cases

- **During an internet shutdown:** MeshTalk allows neighbourhoods, protest groups, or disaster‑struck areas to stay in touch.  
- **Remote areas:** Villages without cellular coverage can create a local mesh using Bluetooth/Wi‑Fi.  
- **Privacy‑focused users:** No central server, no metadata, complete control over data.  
- **Community networks:** Organisations can deploy MeshTalk as a free, self‑contained communication system.  
- **Emergency response:** SOS mode and live location sharing help coordinate rescue efforts.

---

## 14. Summary

MeshTalk is a fully functional, serverless, offline‑first messaging app that combines local mesh, internet P2P, strong encryption, and a familiar UI. It gives you complete control over your communication, even when infrastructure fails. After full development, it will be a powerful tool for individuals, communities, and organisations seeking resilient and private messaging.

---

## 💻 Developer Guide: How to Push Code Updates

Whenever you make changes to the source code of OffTalk (for example, adding a new feature or fixing a bug) and you want to save these changes to your GitHub repository and trigger new builds, follow these 3 very simple terminal commands:

1. **Prepare all your changes to be saved:**
   ```bash
   git add .
   ```

2. **Wrap your changes up in a "commit" with a description:**
   ```bash
   git commit -m "Describe what changes you made here"
   ```

3. **Upload (push) your committed changes to GitHub:**
   ```bash
   git push origin main
   ```

**That's it!** If you have GitHub Actions configured (via `.github/workflows`), your code will instantly start compiling a brand new APK online.
