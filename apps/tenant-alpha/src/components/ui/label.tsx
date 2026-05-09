import * as React from 'react'
import { cn } from '@olonjs/core/runtime'

const Label = React.forwardRef<
  HTMLLabelElement,
  React.LabelHTMLAttributes<HTMLLabelElement>
>(({ className, ...props }, ref) => (
  <label
    ref={ref}
    className={cn('block text-xs font-medium text-foreground mb-1.5 cursor-default', className)}
    {...props}
  />
))
Label.displayName = 'Label'

export { Label }
