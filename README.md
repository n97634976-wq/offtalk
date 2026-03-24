  OffTalk
</h1>

<p align="center">
  <strong>The Ultimate Offline-First, Serverless, Peer-to-Peer Messenger</strong><br>
  <img src="https://img.shields.io/badge/Status-Beta_v1.0.0-blue.svg">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-brightgreen.svg">
  <img src="https://img.shields.io/badge/License-MIT-orange.svg">
</p>

## 🌟 What is OffTalk?
OffTalk is a revolutionary messaging application designed to operate **100% without internet or cellular networks**. It uses your phone's built-in Bluetooth Low Energy (BLE) and Wi-Fi Direct hardware to form an encrypted, localized peer-to-peer mesh network.

When internet *is* available, it bridges transparently over a global `libp2p` overlay. No servers. No phone numbers collected. Complete encryption.

OffTalk is fully open-source. Anyone can contribute! 
Feel free to open an Issue or submit a Pull Request. Currently looking for help with iOS MultipeerConnectivity!

## ✨ Features
- 📶 **True Offline Messaging**: Uses BLE multi-hop routing and Wi-Fi Direct.
- 🔒 **End-to-End Encryption**: Themis Secure Session (ECDH forward secrecy).
- 🧑‍🤝‍🧑 **Group Chats**: Fully encrypted AES-256 group messaging.
- 📷 **High-Speed Media**: Transfer compressed images and files over Wi-Fi Direct.
- 🗺️ **Offline Maps & SOS**: View your peers on an offline map and trigger emergency SOS broadcasts to everyone nearby.
- 🔗 **Easy Invites**: Add friends via QR Codes, NFC bumps, or Share Links!
- 🔐 **Persistent Login**: Encrypted database protected by your custom PIN.

---

## 📥 How to Download & Install

**For Android (APK)**
1. Go to our [Releases Page](https://github.com/offtalk/offtalk/releases) (placeholder link).
2. Download the latest `OffTalk-beta-v1.0.0.apk`.
3. Open the file on your Android device (you may need to allow "Install from Unknown Sources" in your settings).
4. Launch OffTalk and set up your PIN!

**For iOS (App Store / TestFlight)**
*Coming soon! Since mesh routing requires specific background permissions, Apple review is pending. Stay tuned.*

---

## 🛠️ Build it Yourself (Developers)
If you want to compile the code on your own machine, you'll need [Flutter](https://docs.flutter.dev/get-started/install).

1. Clone the repository:
   \`\`\`bash
   git clone https://github.com/offtalk/offtalk.git
   cd offtalk
   \`\`\`
2. (Linux/Mac script) Use the automated APK build script:
   \`\`\`bash
   chmod +x build_apk.sh
   ./build_apk.sh
   \`\`\`
3. Or manually:
   \`\`\`bash
   flutter pub get
   flutter build apk --release
   \`\`\`

---
*Built with ❤️ in Flutter. Dedicated to secure and accessible communication.*
