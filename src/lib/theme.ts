import { Lang } from './i18n';

export interface AppSettings {
  darkMode: boolean;
  language: Lang;
  accentColor: string;
}

export const defaultSettings: AppSettings = {
  darkMode: true,
  language: 'en',
  accentColor: '#00a884'
};

export const darkTheme = {
  bg: '#111b21',
  bgSecondary: '#202c33',
  bgTertiary: '#2a3942',
  bgChat: '#0b141a',
  text: '#e9edef',
  textSecondary: '#8696a0',
  textMuted: '#aebac1',
  accent: '#00a884',
  accentHover: '#008f6f',
  danger: '#ea0038',
  sentBubble: '#005c4b',
  receivedBubble: '#202c33',
  border: '#2a3942',
  tickRead: '#53bdeb',
};

export const lightTheme = {
  bg: '#ffffff',
  bgSecondary: '#f0f2f5',
  bgTertiary: '#e9edef',
  bgChat: '#efeae2',
  text: '#111b21',
  textSecondary: '#667781',
  textMuted: '#8696a0',
  accent: '#00a884',
  accentHover: '#008f6f',
  danger: '#ea0038',
  sentBubble: '#d9fdd3',
  receivedBubble: '#ffffff',
  border: '#e9edef',
  tickRead: '#53bdeb',
};

export type Theme = typeof darkTheme;

export function getTheme(isDark: boolean): Theme {
  return isDark ? darkTheme : lightTheme;
}
