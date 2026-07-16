import * as React from 'react';
import { createPortal } from 'react-dom';
import { cn } from '@olonjs/core';

type DialogContextValue = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
};

const DialogContext = React.createContext<DialogContextValue | null>(null);

function useDialogContext() {
  const ctx = React.useContext(DialogContext);
  if (!ctx) throw new Error('Dialog components must be used within Dialog');
  return ctx;
}

interface DialogProps {
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
  children: React.ReactNode;
}

function Dialog({ open: controlledOpen, onOpenChange, children }: DialogProps) {
  const [uncontrolledOpen, setUncontrolledOpen] = React.useState(false);
  const isControlled = controlledOpen !== undefined;
  const open = isControlled ? controlledOpen : uncontrolledOpen;
  const setOpen = React.useCallback(
    (next: boolean) => {
      if (!isControlled) setUncontrolledOpen(next);
      onOpenChange?.(next);
    },
    [isControlled, onOpenChange]
  );

  const value = React.useMemo(() => ({ open, onOpenChange: setOpen }), [open, setOpen]);
  return (
    <DialogContext.Provider value={value}>
      {children}
    </DialogContext.Provider>
  );
}

interface DialogTriggerProps {
  asChild?: boolean;
  children: React.ReactNode;
}

function DialogTrigger({ asChild, children }: DialogTriggerProps) {
  const { onOpenChange } = useDialogContext();
  const child = React.Children.only(children) as React.ReactElement<{ onClick?: (e: React.MouseEvent) => void }>;
  if (asChild && React.isValidElement(child)) {
    return React.cloneElement(child, {
      onClick: (e: React.MouseEvent) => {
        child.props.onClick?.(e);
        onOpenChange(true);
      },
    });
  }
  return (
    <button type="button" onClick={() => onOpenChange(true)}>
      {children}
    </button>
  );
}

interface DialogContentProps extends React.ComponentProps<'div'> {
  className?: string;
  children?: React.ReactNode;
  /** When true, clicking the backdrop does not close the dialog (e.g. during upload flow). */
  preventCloseOnBackdropClick?: boolean;
}

function DialogContent({ className, children, preventCloseOnBackdropClick, ...props }: DialogContentProps) {
  const { open, onOpenChange } = useDialogContext();

  React.useEffect(() => {
    const onEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onOpenChange(false);
    };
    if (open) {
      document.addEventListener('keydown', onEscape);
      document.body.style.overflow = 'hidden';
    }
    return () => {
      document.removeEventListener('keydown', onEscape);
      document.body.style.overflow = '';
    };
  }, [open, onOpenChange]);

  if (!open) return null;

  const blockDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  return createPortal(
    <>
      <div
        className="fixed inset-0 z-[9998] bg-black/60"
        aria-hidden
        onClick={() => !preventCloseOnBackdropClick && onOpenChange(false)}
        onDragOver={blockDrop}
        onDrop={blockDrop}
      />
      <div
        role="dialog"
        aria-modal
        className={cn(
          'fixed left-1/2 top-1/2 z-[9999] w-[calc(100%-2rem)] max-w-lg -translate-x-1/2 -translate-y-1/2 rounded-lg border border-zinc-700 bg-zinc-900 p-4 shadow-xl',
          className
        )}
        onClick={(e) => e.stopPropagation()}
        {...props}
      >
        {children}
      </div>
    </>,
    document.body
  );
}

function DialogHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return <div className={cn('flex flex-col gap-1.5 pb-4', className)} {...props} />;
}

function DialogFooter({ className, ...props }: React.ComponentProps<'div'>) {
  return <div className={cn('flex justify-end gap-2 pt-4', className)} {...props} />;
}

function DialogTitle({ className, ...props }: React.ComponentProps<'h2'>) {
  return <h2 className={cn('text-sm font-semibold text-white', className)} {...props} />;
}

function DialogDescription({ className, ...props }: React.ComponentProps<'p'>) {
  return <p className={cn('text-xs text-zinc-400', className)} {...props} />;
}

interface DialogCloseProps {
  asChild?: boolean;
  children: React.ReactNode;
}

function DialogClose({ asChild, children }: DialogCloseProps) {
  const { onOpenChange } = useDialogContext();
  const child = React.Children.only(children) as React.ReactElement<{ onClick?: (e: React.MouseEvent) => void }>;
  if (asChild && React.isValidElement(child)) {
    return React.cloneElement(child, {
      onClick: (e: React.MouseEvent) => {
        child.props.onClick?.(e);
        onOpenChange(false);
      },
    });
  }
  return (
    <button type="button" onClick={() => onOpenChange(false)}>
      {children}
    </button>
  );
}

export { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogFooter, DialogTitle, DialogDescription, DialogClose };
