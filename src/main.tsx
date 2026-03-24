if (typeof global === 'undefined') {
  (window as any).global = window;
}
if (typeof process === 'undefined') {
  (window as any).process = { env: {} };
}
if (typeof Buffer === 'undefined') {
  (window as any).Buffer = [];
}

import {StrictMode} from 'react';
import {createRoot} from 'react-dom/client';
import App from './App.tsx';
import './index.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
