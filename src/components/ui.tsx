import React from 'react';
import { Theme } from '../lib/theme';

export const Button = ({ children, onClick, className = '', variant = 'primary', theme }: any) => {
  const variants: any = {
    primary: `bg-[${theme?.accent||'#00a884'}] text-white hover:opacity-90`,
    secondary: `bg-[${theme?.bgTertiary||'#2a3942'}] text-[${theme?.textMuted||'#aebac1'}] hover:opacity-80`,
    danger: 'bg-[#ea0038] text-white hover:bg-[#c0002e]',
    ghost: `bg-transparent text-[${theme?.textMuted||'#aebac1'}] hover:opacity-80`
  };
  return (
    <button
      onClick={onClick}
      className={`px-4 py-2 rounded-lg font-medium transition-all flex items-center justify-center gap-2 ${variants[variant]} ${className}`}
    >
      {children}
    </button>
  );
};

export const Avatar = ({ name, size = 'md', theme }: { name: string; size?: 'sm' | 'md' | 'lg'; theme?: Theme }) => {
  const sizes = { sm: 'w-8 h-8 text-xs', md: 'w-12 h-12 text-base', lg: 'w-24 h-24 text-2xl' };
  const colors = ['#6a7175','#25d366','#128c7e','#075e54','#34b7f1','#00a884','#7c3aed','#ec4899'];
  const idx = name ? name.charCodeAt(0) % colors.length : 0;
  return (
    <div className={`${sizes[size]} rounded-full flex items-center justify-center text-white font-bold uppercase shrink-0`}
         style={{backgroundColor: colors[idx]}}>
      {(name||'?').charAt(0)}
    </div>
  );
};

export const Modal = ({ children, onClose, theme }: { children: React.ReactNode; onClose: () => void; theme: Theme }) => (
  <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60" onClick={onClose}>
    <div className="rounded-2xl p-6 w-full max-w-md mx-4 shadow-2xl" 
         style={{backgroundColor: theme.bgSecondary, color: theme.text}}
         onClick={e => e.stopPropagation()}>
      {children}
    </div>
  </div>
);

export const TabBar = ({ tabs, active, onChange, theme }: { tabs: {id:string;label:string}[]; active:string; onChange:(id:string)=>void; theme:Theme }) => (
  <div className="flex border-b" style={{borderColor: theme.border}}>
    {tabs.map(tab => (
      <button key={tab.id} onClick={() => onChange(tab.id)}
        className="flex-1 py-3 text-sm font-medium transition-colors"
        style={{
          color: active === tab.id ? theme.accent : theme.textSecondary,
          borderBottom: active === tab.id ? `2px solid ${theme.accent}` : '2px solid transparent'
        }}>
        {tab.label}
      </button>
    ))}
  </div>
);
