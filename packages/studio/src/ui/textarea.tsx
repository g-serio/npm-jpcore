import * as React from 'react';
import { cn } from '@olonjs/core';

function Textarea({ className, ...props }: React.ComponentProps<'textarea'>) {
  return (
    <textarea
      className={cn(
        'min-h-16 w-full rounded-lg border border-zinc-800 bg-zinc-900/50 px-2.5 py-2 text-sm text-zinc-100 outline-none transition-colors focus:ring-2 focus:ring-blue-600 resize-none',
        className
      )}
      {...props}
    />
  );
}

export { Textarea };
