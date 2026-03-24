import CryptoJS from 'crypto-js';

export const generateKeyPair = () => {
  // In a real app, we'd use Web Crypto API for ECDH
  // For this demo, we'll simulate keys with random strings
  const privateKey = CryptoJS.lib.WordArray.random(32).toString();
  const publicKey = CryptoJS.SHA256(privateKey).toString();
  return { privateKey, publicKey };
};

export const generateGroupKey = () => {
  return CryptoJS.lib.WordArray.random(32).toString();
};

export const encryptMessage = (text: string, secretKey: string) => {
  return CryptoJS.AES.encrypt(text, secretKey).toString();
};

export const decryptMessage = (cipherText: string, secretKey: string) => {
  const bytes = CryptoJS.AES.decrypt(cipherText, secretKey);
  return bytes.toString(CryptoJS.enc.Utf8);
};

export const deriveSharedSecret = (myPrivateKey: string, theirPublicKey: string) => {
  // Simulated ECDH
  return CryptoJS.SHA256(myPrivateKey + theirPublicKey).toString();
};
