'use client';

import { ArrowRight } from 'lucide-react';
import { motion, useReducedMotion } from 'motion/react';
import type { CSSProperties, ReactNode, SVGProps } from 'react';
import { useEffect, useMemo, useState } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { cn } from '@/lib/utils';
import type { PremiumCtaData, PremiumCtaSettings } from './types';

/** Deterministic 0–1 floats so SSR and client render identical particle props. */
function createSeededRandom(seed: number) {
  let state = Math.floor(Math.abs(seed)) % 2_147_483_646;
  if (state === 0) {
    state = 1;
  }
  return () => {
    state = (state * 16_807) % 2_147_483_647;
    return (state - 1) / 2_147_483_646;
  };
}

const useMobile = () => {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => window.innerWidth < 768;
    setIsMobile(checkMobile());
    const handleResize = () => setIsMobile(checkMobile());
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  return isMobile;
};

const FloatingElement = ({
  children,
  className,
  delay = 0,
  duration = 4,
  yOffset = 8,
  xOffset = 0,
}: {
  children: ReactNode;
  className?: string;
  delay?: number;
  duration?: number;
  yOffset?: number;
  xOffset?: number;
}) => {
  const prefersReducedMotion = useReducedMotion();

  if (prefersReducedMotion) {
    return <div className={className}>{children}</div>;
  }

  return (
    <motion.div
      animate={{
        y: [0, -yOffset, 0],
        x: [0, xOffset, 0],
      }}
      className={className}
      initial={{ y: 0, x: 0 }}
      transition={{
        duration,
        repeat: Number.POSITIVE_INFINITY,
        repeatType: 'reverse',
        ease: [0.4, 0.0, 0.2, 1],
        delay,
      }}
    >
      {children}
    </motion.div>
  );
};

const GlowingBlob = ({
  color,
  size = 200,
  top,
  left,
  right,
  bottom,
  delay = 0,
  opacity = 0.15,
  blur = 60,
  duration = 8,
}: {
  color: string;
  size?: number;
  top?: string;
  left?: string;
  right?: string;
  bottom?: string;
  delay?: number;
  opacity?: number;
  blur?: number;
  duration?: number;
}) => {
  const prefersReducedMotion = useReducedMotion();

  return (
    <motion.div
      animate={{
        scale: prefersReducedMotion ? 1 : [0.8, 1.1, 0.8],
        opacity,
      }}
      className="pointer-events-none absolute rounded-full"
      exit={{
        scale: prefersReducedMotion ? 1 : [0.8, 1.1, 0.8],
        opacity: 0,
        transition: {
          duration: 1.8,
          delay: delay * 0.5,
        },
      }}
      initial={{ scale: 0.8, opacity: 0 }}
      style={{
        width: size,
        height: size,
        top,
        left,
        right,
        bottom,
        background: color,
        filter: `blur(${blur}px)`,
        opacity: 0,
      }}
      transition={{
        scale: {
          duration,
          repeat: Number.POSITIVE_INFINITY,
          repeatType: 'reverse',
          ease: 'easeInOut',
          delay,
        },
        opacity: {
          duration: 1.8,
          delay: delay * 0.5,
        },
      }}
    />
  );
};

const Button3D = ({
  children,
  variant = 'primary',
  icon,
  href = '#',
  className,
  delay = 0,
  jpHrefField,
  jpLabelField,
}: {
  children: ReactNode;
  variant?: 'primary' | 'secondary';
  icon?: ReactNode;
  href?: string;
  className?: string;
  delay?: number;
  jpHrefField?: string;
  jpLabelField?: string;
}) => {
  const [isHovered, setIsHovered] = useState(false);
  const [isPressed, setIsPressed] = useState(false);
  const [isFocused, setIsFocused] = useState(false);

  const prefersReducedMotion = useReducedMotion();

  const buttonStyles = useMemo(() => {
    const styles: CSSProperties = {
      transformStyle: 'preserve-3d',
      transform: isPressed ? 'translateY(1px)' : 'translateY(0)',
    };

    if (isPressed) {
      styles.boxShadow = 'none';
    } else if (variant === 'primary') {
      styles.boxShadow = '0 4px 10px rgba(0, 0, 0, 0.15)';
    } else {
      styles.boxShadow = 'none';
    }

    return styles;
  }, [isPressed, variant]);

  return (
    <motion.a
      animate={{
        opacity: 1,
        y: 0,
        scale: 1,
        transition: {
          duration: 0.6,
          ease: [0.23, 1, 0.32, 1],
          delay,
        },
      }}
      aria-label={typeof children === 'string' ? children : 'Button'}
      className={cn(
        'group relative overflow-hidden rounded-full',
        'inline-flex items-center justify-center',
        'px-5 py-2.5 font-medium text-sm',
        'transition-all duration-200',
        'focus:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2',
        variant === 'primary'
          ? 'bg-primary text-primary-foreground'
          : 'border border-input bg-background text-foreground',
        className,
      )}
      data-jp-field={jpHrefField}
      href={href}
      initial={{ opacity: 0, y: 15, scale: 0.95 }}
      onBlur={() => setIsFocused(false)}
      onFocus={() => setIsFocused(true)}
      onMouseDown={() => setIsPressed(true)}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      onMouseUp={() => setIsPressed(false)}
      onTouchEnd={() => setIsPressed(false)}
      onTouchStart={() => setIsPressed(true)}
      role="button"
      style={buttonStyles}
      whileHover={{
        scale: prefersReducedMotion ? 1 : 1.03,
        y: prefersReducedMotion ? 0 : -2,
        transition: { duration: 0.2 },
      }}
      whileTap={{
        scale: 0.97,
        y: 1,
        transition: { duration: 0.1 },
      }}
    >
      <motion.div
        animate={{ opacity: isHovered || isFocused ? 1 : 0 }}
        className={cn(
          'absolute inset-0 opacity-0 transition-opacity',
          variant === 'primary' ? 'bg-white/10' : 'bg-black/5',
        )}
        transition={{ duration: 0.2 }}
      />

      <span className="relative z-10 flex items-center gap-2">
        <span data-jp-field={jpLabelField}>{children}</span>
        {icon && (
          <motion.span
            animate={{
              x: (isHovered || isFocused) && !prefersReducedMotion ? 3 : 0,
              scale: (isHovered || isFocused) && !prefersReducedMotion ? 1.1 : 1,
            }}
            transition={{ duration: 0.2 }}
          >
            {icon}
          </motion.span>
        )}
      </span>
    </motion.a>
  );
};

const AnimatedText = ({
  text,
  className,
  delay = 0,
  staggerChildren = 0.03,
  fontSize = 'text-2xl',
  fontWeight = 'font-bold',
  dataJpField,
}: {
  text: string;
  className?: string;
  delay?: number;
  staggerChildren?: number;
  fontSize?: string;
  fontWeight?: string;
  dataJpField?: string;
}) => {
  const words = text.split(' ');
  const prefersReducedMotion = useReducedMotion();

  if (prefersReducedMotion) {
    return (
      <span className={cn(fontSize, fontWeight, className)} data-jp-field={dataJpField}>
        {text}
      </span>
    );
  }

  return (
    <span className={cn(fontSize, fontWeight, className)} data-jp-field={dataJpField}>
      {words.map((word, i) => (
        <span className="mr-[0.25em] inline-block overflow-hidden pb-0.5 text-[var(--local-on-surface)]" key={i}>
          <motion.span
            animate={{
              y: 0,
              opacity: 1,
              rotateX: 0,
            }}
            className="inline-block"
            initial={{ y: 35, opacity: 0, rotateX: 15 }}
            transition={{
              duration: 0.7,
              ease: [0.23, 1, 0.32, 1],
              delay: delay + i * staggerChildren,
            }}
          >
            {word}
          </motion.span>
        </span>
      ))}
    </span>
  );
};


const CardGridBackground = ({ isDark }: { isDark: boolean }) => {
  const prefersReducedMotion = useReducedMotion();

  if (prefersReducedMotion) {
    return null;
  }

  return (
    <motion.div
      animate={{
        opacity: 1,
        transition: { duration: 1.5 },
      }}
      className="absolute inset-0 overflow-hidden rounded-xl"
      initial={{ opacity: 0 }}
    >
      <motion.div
        animate={{
          rotateX: 60,
          y: 0,
          opacity: 0.4,
          transition: {
            duration: 1.2,
            ease: [0.23, 1, 0.32, 1],
          },
        }}
        className="absolute inset-x-0 bottom-0 h-[700px]"
        initial={{ rotateX: 65, y: 20, opacity: 0 }}
        style={{
          perspective: 800,
          transformStyle: 'preserve-3d',
          transformOrigin: 'center bottom',
        }}
      >
        <div
          className="h-full w-full"
          style={{
            backgroundSize: '20px 20px',
            backgroundImage: isDark
              ? 'linear-gradient(to right, rgba(255,255,255,0.05) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,255,255,0.05) 1px, transparent 1px)'
              : 'linear-gradient(to right, rgba(0,0,0,0.03) 1px, transparent 1px), linear-gradient(to bottom, rgba(0,0,0,0.03) 1px, transparent 1px)',
          }}
        />
      </motion.div>
    </motion.div>
  );
};

const Particles = ({
  count = 12,
  isDark = false,
}: {
  count?: number;
  isDark?: boolean;
}) => {
  const prefersReducedMotion = useReducedMotion();

  if (prefersReducedMotion) {
    return null;
  }

  const particles = useMemo(() => {
    const rand = createSeededRandom(3_347_140_609);
    return Array.from({ length: count }).map((_, i) => {
      const size = rand() * 2 + 1;
      const duration = rand() * 10 + 15;
      const initialX = rand() * 100;
      const initialY = rand() * 100;
      const delay = rand() * 5;
      const endXDelta = rand() * 8 - 4;
      const endYDelta = rand() * 12;

      return {
        id: i,
        size,
        duration,
        initialX,
        initialY,
        delay,
        endX: initialX + endXDelta,
        endY: initialY - endYDelta,
      };
    });
  }, [count]);

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {particles.map(({ id, size, duration, initialX, initialY, delay, endX, endY }) => (
        <motion.div
          animate={{
            x: [`${initialX}%`, `${endX}%`],
            y: [`${initialY}%`, `${endY}%`],
            opacity: [0, 0.3, 0],
          }}
          className={`absolute rounded-full ${isDark ? 'bg-white/8' : 'bg-black/4'}`}
          initial={{ opacity: 0 }}
          key={id}
          style={{
            width: `${size}px`,
            height: `${size}px`,
            x: `${initialX}%`,
            y: `${initialY}%`,
          }}
          transition={{
            duration,
            ease: 'linear',
            repeat: Number.POSITIVE_INFINITY,
            delay,
          }}
        />
      ))}
    </div>
  );
};


function AIIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg fill="none" height={24} viewBox="0 0 24 24" width={24} xmlns="http://www.w3.org/2000/svg" {...props}>
      <path
        d="M11.5 6C7.02166 6 4.78249 6 3.39124 7.17157C2 8.34315 2 10.2288 2 14C2 17.7712 2 19.6569 3.39124 20.8284C4.78249 22 7.02166 22 11.5 22C15.9783 22 18.2175 22 19.6088 20.8284C21 19.6569 21 17.7712 21 14C21 12.8302 21 11.8419 20.9585 11"
        stroke="currentColor"
        strokeLinecap="round"
        strokeWidth="1.5"
      />
      <path
        d="M18.5 2L18.7579 2.69703C19.0961 3.61102 19.2652 4.06802 19.5986 4.40139C19.932 4.73477 20.389 4.90387 21.303 5.24208L22 5.5L21.303 5.75792C20.389 6.09613 19.932 6.26524 19.5986 6.59861C19.2652 6.93198 19.0961 7.38898 18.7579 8.30297L18.5 9L18.2421 8.30297C17.9039 7.38898 17.7348 6.93198 17.4014 6.59861C17.068 6.26524 16.611 6.09613 15.697 5.75792L15 5.5L15.697 5.24208C16.611 4.90387 17.068 4.73477 17.4014 4.40139C17.7348 4.06802 17.9039 3.61102 18.2421 2.69703L18.5 2Z"
        opacity="0.4"
        stroke="currentColor"
        strokeLinejoin="round"
        strokeWidth="1.5"
      />
      <path d="M12 10V18" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" />
      <path
        d="M9 12V16"
        opacity="0.4"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.5"
      />
      <path d="M6 13V15" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" />
      <path
        d="M15 12V16"
        opacity="0.4"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.5"
      />
      <path d="M18 13V15" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" />
    </svg>
  );
}

type PremiumCtaViewProps = {
  data: PremiumCtaData;
  settings?: PremiumCtaSettings;
};

export function PremiumCtaView({ data }: PremiumCtaViewProps) {
  const prefersReducedMotion = useReducedMotion();
  const isMobile = useMobile();
  const [isHovered, setIsHovered] = useState(false);

  const cardShadowStyle = useMemo(() => {
    const shadowStyle: CSSProperties = {};

    // Uniform 1px inset ring + symmetric elevation (avoid 1px Y-offset shadows that read as uneven borders)
    if (isHovered && !prefersReducedMotion) {
      shadowStyle.boxShadow =
        'inset 0 0 0 1px color-mix(in oklab, var(--local-border) 40%, transparent), 0px 20px 50px -12px rgba(0, 0, 0, 0.15)';
    } else {
      shadowStyle.boxShadow =
        'inset 0 0 0 1px color-mix(in oklab, var(--local-border) 35%, transparent), 0px 12px 40px -16px rgba(0, 0, 0, 0.12)';
    }

    return shadowStyle;
  }, [isHovered, prefersReducedMotion]);

  const rootStyle = {
    '--local-bg': 'var(--background)',
    '--local-text': 'var(--foreground)',
    '--local-muted': 'var(--muted-foreground)',
    '--local-border': 'var(--border)',
    '--local-surface': 'var(--card)',
    '--local-on-surface': 'var(--card-foreground)',
    '--local-radius': 'var(--theme-border-radius-md, 0.5rem)',
  } as CSSProperties;

  return (
    <section
      className="flex w-full flex-col items-center justify-center bg-[var(--local-bg)] px-6 py-16 text-[var(--local-text)] md:py-24 lg:py-28"
      style={rootStyle}
    >
      <div className="sr-only" aria-hidden>
        <span data-jp-field="socialProofLine">{data.socialProofLine}</span>
        <span data-jp-field="socialProofHighlight">{data.socialProofHighlight}</span>
      </div>
      <div className="flex w-full max-w-5xl flex-col items-center space-y-10">
      <motion.div
        animate={{
          opacity: 1,
          y: 0,
          transition: {
            duration: 0.8,
            ease: [0.23, 1, 0.32, 1],
          },
        }}
        className="w-full"
        initial={{ opacity: 0, y: 30 }}
        onHoverEnd={() => setIsHovered(false)}
        onHoverStart={() => setIsHovered(true)}
      >
        <Card
          className="relative overflow-hidden rounded-[var(--local-radius)] border border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-on-surface)] transition-shadow duration-500 ease-out lg:rounded-4xl"
          style={cardShadowStyle}
        >
          <div className="absolute inset-0 z-0 overflow-hidden rounded-lg lg:rounded-4xl">
            <CardGridBackground isDark={false} />
            <Particles count={isMobile ? 8 : 12} isDark={false} />

            {!prefersReducedMotion && (
              <>
                <GlowingBlob
                  blur={isHovered ? 70 : 50}
                  color="#8b5cf680"
                  delay={0.2}
                  duration={10}
                  left="-5%"
                  opacity={isHovered ? 0.65 : 0.15}
                  size={400}
                  top="-15%"
                />

                <GlowingBlob
                  blur={60}
                  bottom="-10%"
                  color="#ec489980"
                  delay={0.5}
                  duration={12}
                  opacity={isHovered ? 0.55 : 0.25}
                  right="-5%"
                  size={350}
                />
                <GlowingBlob
                  blur={80}
                  bottom="20%"
                  color="#3b82f680"
                  delay={0.8}
                  duration={15}
                  opacity={isHovered ? 0.55 : 0.25}
                  right="15%"
                  size={300}
                />
              </>
            )}
          </div>

          <CardContent className="relative z-10 p-8 sm:p-10 lg:p-12">
            <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between lg:text-left">
              <div className="flex flex-col items-center text-center lg:max-w-xl lg:items-start lg:text-left">
                <FloatingElement className="mb-4 text-[var(--local-on-surface)]" delay={0.5} yOffset={5}>
                  <motion.div
                    animate={{
                      scale: 1,
                      rotate: 0,
                      transition: {
                        type: 'spring',
                        stiffness: 300,
                        damping: 15,
                        delay: 0.2,
                      },
                    }}
                    initial={{ scale: 0, rotate: -20 }}
                  >
                    <AIIcon className="size-6 md:size-8 xl:size-10" />
                  </motion.div>
                </FloatingElement>

                <div className="mb-6 space-y-4 lg:mb-8">
                  <h2 className="leading-tight tracking-tight text-[var(--local-on-surface)]">
                    <AnimatedText
                      className="pb-2 lg:text-left"
                      dataJpField="headingLight"
                      delay={0.3}
                      fontSize="text-2xl sm:text-3xl lg:text-4xl "
                      fontWeight="font-light"
                      text={data.headingLight}
                    />
                    <br />
                    <AnimatedText
                      className="lg:text-left"
                      dataJpField="headingBold"
                      delay={0.5}
                      fontSize="text-2xl sm:text-3xl lg:text-4xl"
                      fontWeight="font-bold"
                      text={data.headingBold}
                    />
                  </h2>

                  <motion.p
                    animate={{
                      opacity: 1,
                      y: 0,
                      transition: {
                        type: 'spring',
                        stiffness: 100,
                        damping: 15,
                        delay: 0.7,
                      },
                    }}
                    className="mx-auto max-w-md text-sm text-[var(--local-muted)] sm:text-base lg:mx-0 lg:pr-4"
                    data-jp-field="body"
                    initial={{ opacity: 0, y: 20 }}
                  >
                    {data.body}
                  </motion.p>
                </div>

              </div>

              <div className="flex flex-col lg:ml-8 lg:min-w-[240px] lg:items-end xl:ml-12">
                <div className="flex w-full flex-col gap-3">
                  <Button3D
                    className="w-full"
                    delay={0.9}
                    href={data.primaryCta.href}
                    icon={<ArrowRight size={14} />}
                    jpHrefField="primaryCta.href"
                    jpLabelField="primaryCta.label"
                    variant="primary"
                  >
                    {data.primaryCta.label}
                  </Button3D>

                  <Button3D
                    className="w-full"
                    delay={1.0}
                    href={data.secondaryCta.href}
                    jpHrefField="secondaryCta.href"
                    jpLabelField="secondaryCta.label"
                    variant="secondary"
                  >
                    {data.secondaryCta.label}
                  </Button3D>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </div>
    </section>
  );
}
