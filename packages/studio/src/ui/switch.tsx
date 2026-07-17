import * as React from 'react';
import { cn } from '@olonjs/core';

interface SwitchProps extends Omit<React.ComponentProps<'button'>, 'onChange'> {
  checked?: boolean;
  onCheckedChange?: (checked: boolean) => void;
}

const Switch = React.forwardRef<HTMLButtonElement, SwitchProps>(
  ({ className, checked = false, onCheckedChange, ...props }, ref) => {
    const handleClick = () => onCheckedChange?.(!checked);
    return (
      <button
        ref={ref}
        type="button"
        role="switch"
        aria-checked={checked}
        data-state={checked ? 'checked' : 'unchecked'}
        onClick={handleClick}
        className={cn(
          'peer inline-flex h-4 w-7 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent shadow-sm transition-colors',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-zinc-900',
          'disabled:cursor-not-allowed disabled:opacity-50',
          checked ? 'bg-blue-600' : 'bg-zinc-700',
          className
        )}
        {...props}
      >
        <span
          className={cn(
            'pointer-events-none block h-3 w-3 rounded-full bg-white shadow ring-0 transition-transform',
            checked ? 'translate-x-3' : 'translate-x-0.5'
          )}
        />
      </button>
    );
  }
);
Switch.displayName = 'Switch';

export { Switch };
