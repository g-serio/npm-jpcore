import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cn } from '@olonjs/core';

interface ButtonProps extends React.ComponentProps<'button'> {
  variant?: 'default' | 'outline' | 'ghost' | 'destructive';
  size?: 'sm' | 'default' | 'lg' | 'icon' | 'icon-sm' | 'icon-xs';
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'default', size = 'default', asChild = false, ...props }, ref) => {
    const base =
      'inline-flex items-center justify-center gap-1.5 whitespace-nowrap rounded-md font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 [&_svg]:shrink-0 cursor-pointer';
    const variants: Record<NonNullable<ButtonProps['variant']>, string> = {
      default: 'bg-primary text-primary-foreground shadow-lg shadow-primary/20 hover:bg-primary/90',
      outline: 'border border-zinc-700 bg-zinc-900 text-zinc-200 hover:bg-zinc-800 hover:border-zinc-600',
      ghost: 'text-zinc-500 hover:text-zinc-200 hover:bg-zinc-800',
      destructive: 'bg-destructive/15 text-destructive hover:bg-destructive/25',
    };
    const sizes: Record<NonNullable<ButtonProps['size']>, string> = {
      sm: 'h-7 px-2.5 text-[11px]',
      default: 'h-8 px-3 py-1.5 text-xs',
      lg: 'h-9 px-5 text-sm',
      icon: 'h-8 w-8',
      'icon-sm': 'h-7 w-7',
      'icon-xs': 'h-6 w-6',
    };
    const Comp = asChild ? Slot : 'button';
    return (
      <Comp
        ref={ref}
        type="button"
        className={cn(base, variants[variant], sizes[size], className)}
        {...props}
      />
    );
  }
);

Button.displayName = 'Button';

export { Button };
