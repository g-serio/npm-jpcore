import * as React from 'react';
import { cn } from '@olonjs/core';

interface CheckboxProps extends Omit<React.ComponentProps<'input'>, 'type'> {
  checked?: boolean;
  onCheckedChange?: (checked: boolean) => void;
}

function Checkbox({ className, checked, onCheckedChange, ...props }: CheckboxProps) {
  return (
    <input
      type="checkbox"
      checked={checked}
      onChange={(e) => onCheckedChange?.(e.target.checked)}
      className={cn(
        'size-4 rounded border border-zinc-700 bg-zinc-900 text-blue-600 focus:ring-2 focus:ring-blue-600',
        className
      )}
      {...props}
    />
  );
}

export { Checkbox };
