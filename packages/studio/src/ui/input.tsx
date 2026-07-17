import * as React from 'react';
import { cn } from '@olonjs/core';

function Input({ className, type, ...props }: React.ComponentProps<'input'>) {
  return (
    <input
      type={type}
      className={cn(
        'h-8 rounded-lg border border-zinc-800 bg-zinc-900/50 px-2.5 py-1 text-sm text-zinc-100 outline-none transition-colors focus:ring-2 focus:ring-blue-600',
        className
      )}
      {...props}
    />
  );
}

export { Input };
