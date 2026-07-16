import React, { createContext, useContext, useEffect, ReactNode } from 'react';

type StudioMode = 'visitor' | 'studio';

interface StudioContextType {
  mode: StudioMode;
}

const StudioContext = createContext<StudioContextType | undefined>(undefined);

export const StudioProvider: React.FC<{ mode: StudioMode; children: ReactNode }> = ({ mode, children }) => {
  useEffect(() => {
    if (mode !== 'studio') return;

    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node instanceof HTMLElement && node.hasAttribute('data-radix-portal')) {
            node.setAttribute('data-jp-studio-portal', 'true');
          }
        });
      });
    });

    observer.observe(document.body, { childList: true });

    return () => observer.disconnect();
  }, [mode]);

  return (
    <StudioContext.Provider value={{ mode }}>
      {children}
    </StudioContext.Provider>
  );
};

export const useStudio = () => {
  const context = useContext(StudioContext);
  if (context === undefined) {
    throw new Error('useStudio must be used within a StudioProvider');
  }
  return context;
};
