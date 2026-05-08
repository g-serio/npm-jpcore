import { cva } from 'class-variance-authority';
import type { HTMLAttributes, ReactNode } from 'react';
import { cn } from '@/lib/utils';

const gradientVariants = cva('bg-clip-text text-transparent tracking-tight', {
  variants: {
    variant: {
      default: 'bg-gradient-to-t from-primary to-primary/90',
      primaryLight: 'bg-gradient-to-b from-primary-light to-primary',
      helper:
        'bg-gradient-to-t from-muted-foreground via-[#8C8C8C] to-[#B4B4B8] dark:from-muted-foreground dark:to-[#D6D6D6]',
      accent: 'bg-gradient-to-t from-accent to-accent/80 dark:from-accent dark:to-accent/90',
      pink: 'bg-gradient-to-t from-[#fb21ff] to-[#fd67ff] dark:from-[#fb21ff] dark:to-[#fd67ff]',
      blue: 'bg-gradient-to-t from-[hsl(var(--chart-5))] to-[hsl(var(--chart-5))/80] dark:from-[hsl(var(--chart-5))] dark:to-[hsl(var(--chart-5))/90]',
      light: 'bg-gradient-to-t from-neutral-200 to-neutral-300 dark:from-neutral-300 dark:to-neutral-400',
      secondary: 'bg-gradient-to-t from-secondary-foreground to-muted-foreground',
      none: '',
    },
    weight: {
      default: 'font-bold',
      thin: 'font-thin',
      base: 'font-normal',
      semi: 'font-semibold',
      bold: 'font-bold',
      black: 'font-black',
    },
  },
  defaultVariants: {
    variant: 'none',
    weight: 'default',
  },
});

export type GradientVariant =
  | 'default'
  | 'primaryLight'
  | 'helper'
  | 'accent'
  | 'pink'
  | 'blue'
  | 'light'
  | 'secondary'
  | 'none';
export type FontWeight = 'default' | 'thin' | 'base' | 'semi' | 'bold' | 'black';

export interface TextLink {
  text: string;
  href: string;
}

export interface TwoToneTextProps extends HTMLAttributes<HTMLHeadingElement> {
  primaryText: string;
  secondaryText: string;
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl' | 'xxl' | 'xxxl';
  as?: 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6' | 'p';
  allowWrap?: boolean;
  align?: 'left' | 'center' | 'right';
  primaryGradient?: GradientVariant;
  secondaryGradient?: GradientVariant;
  primaryWeight?: FontWeight;
  secondaryWeight?: FontWeight;
  primaryLinks?: TextLink[];
  secondaryLinks?: TextLink[];
  /** IDAC: schema field key for primary line (optional). */
  primaryDataJpField?: string;
  /** IDAC: schema field key for secondary line (optional). */
  secondaryDataJpField?: string;
}

export function TwoToneHeading({
  primaryText,
  secondaryText,
  size = 'md',
  as: Component = 'h2',
  allowWrap = false,
  align = 'left',
  primaryGradient = 'default',
  secondaryGradient = 'helper',
  primaryWeight = 'semi',
  secondaryWeight = 'semi',
  primaryLinks = [],
  secondaryLinks = [],
  primaryDataJpField,
  secondaryDataJpField,
  className,
  ...props
}: TwoToneTextProps) {
  const sizeClasses = {
    xs: 'text-base leading-[1.2] tracking-tight',
    sm: 'text-xl md:text-2xl leading-[1.2] tracking-tight',
    md: 'text-[20px] md:text-[32px] leading-[1.125] tracking-tight',
    lg: 'text-2xl md:text-[32px] leading-[1.125] tracking-tight',
    xl: 'text-4xl md:text-6xl leading-[1.1] tracking-tight',
    xxl: 'text-6xl md:text-7xl leading-[1.1] tracking-tight',
    xxxl: 'text-7xl md:text-8xl leading-[1.1] tracking-tight',
  };

  const alignmentClasses = {
    left: 'text-left',
    center: 'text-center',
    right: 'text-right',
  };

  const renderTextWithLinks = (
    text: string,
    links: TextLink[],
    gradientVariant: GradientVariant,
    weight: FontWeight
  ) => {
    if (!links.length) {
      return text;
    }

    const linkMap = new Map<number, TextLink & { endIndex: number }>();

    links.forEach((link) => {
      const startIndex = text.indexOf(link.text);
      if (startIndex !== -1) {
        linkMap.set(startIndex, {
          ...link,
          endIndex: startIndex + link.text.length,
        });
      }
    });

    const positions = Array.from(linkMap.keys()).sort((a, b) => a - b);

    if (!positions.length) {
      return text;
    }

    const result: (string | ReactNode)[] = [];
    let lastIndex = 0;

    positions.forEach((position) => {
      const link = linkMap.get(position)!;

      if (position > lastIndex) {
        result.push(text.substring(lastIndex, position));
      }

      result.push(
        <a
          className={cn(
            gradientVariants({ weight, variant: 'none' }),
            gradientVariant === 'none'
              ? 'text-black dark:text-white'
              : gradientVariant === 'helper'
                ? 'text-muted-foreground hover:text-muted-foreground/90'
                : gradientVariant === 'primaryLight'
                  ? 'text-primary-light hover:text-primary-light/90'
                  : 'text-primary hover:text-primary/90',
            'relative inline-block transition-all duration-200',
            'after:absolute after:bottom-0 after:left-0 after:h-[1px] after:w-full after:origin-right after:scale-x-0 after:bg-current after:transition-transform after:duration-300',
            'hover:after:origin-left hover:after:scale-x-100'
          )}
          href={link.href}
          key={position}
        >
          {link.text}
        </a>
      );

      lastIndex = link.endIndex;
    });

    if (lastIndex < text.length) {
      result.push(text.substring(lastIndex));
    }

    return result;
  };

  return (
    <Component className={cn(sizeClasses[size], alignmentClasses[align], className)} {...props}>
      <span
        className={cn(
          primaryGradient === 'none' ? 'text-black dark:text-white' : '',
          gradientVariants({ variant: primaryGradient, weight: primaryWeight })
        )}
        {...(primaryDataJpField ? { 'data-jp-field': primaryDataJpField } : {})}
      >
        {renderTextWithLinks(primaryText, primaryLinks, primaryGradient, primaryWeight)}
      </span>
      {allowWrap && <span className="inline-block"> </span>}
      {!allowWrap && <span className="mt-1 block" />}
      <span
        className={cn(
          secondaryGradient === 'none' ? 'text-[#86868b] dark:text-[#86868b]' : '',
          gradientVariants({
            variant: secondaryGradient,
            weight: secondaryWeight,
          })
        )}
        {...(secondaryDataJpField ? { 'data-jp-field': secondaryDataJpField } : {})}
      >
        {renderTextWithLinks(secondaryText, secondaryLinks, secondaryGradient, secondaryWeight)}
      </span>
    </Component>
  );
}
