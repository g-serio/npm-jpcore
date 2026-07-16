import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const badgeVariants = cva(
  'inline-flex items-center px-2.5 py-0.5 text-xs font-medium transition-colors',
  {
    variants: {
      variant: {
        default:  'bg-primary-900 text-primary-light border border-primary rounded-sm',
        outline:  'bg-elevated text-muted-foreground border border-border rounded-sm',
        accent:   'text-accent border border-border-strong rounded-sm',
        solid:    'bg-primary text-primary-foreground rounded-sm',
        pill:     'bg-elevated text-muted-foreground border border-border rounded-full gap-1.5',
      },
    },
    defaultVariants: { variant: 'default' },
  }
)

export interface BadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />
}

export { Badge, badgeVariants }
