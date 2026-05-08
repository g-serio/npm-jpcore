import { type ComponentType, type FC, lazy, Suspense } from 'react';
import type { SectionType } from '@/types';
import type { SectionComponentPropsMap } from '@/types';
import { EmptyTenantView } from '@/components/empty-tenant';
import { FooterView } from '@/components/footer';
import { HeaderView } from '@/components/header';
import { PremiumHeroView } from '@/components/premium-hero';

// Lazy wrapper for named-export Section Views. See ADR-0007: sections that are
// not guaranteed above the fold are split into their own chunks and resolved on
// demand. The fallback renders nothing — the engine wraps each section in a
// SectionErrorBoundary, but does not provide a Suspense boundary, so we wrap
// per-section here. CLS stays at 0 because lazy sections sit below the fold and
// their absence during the brief load window doesn't shift visible layout.
function lazySection<P extends object>(
  loader: () => Promise<Record<string, unknown>>,
  exportName: string,
): FC<P> {
  const Lazy = lazy(() =>
    loader().then((mod) => ({ default: mod[exportName] as ComponentType<P> })),
  );
  const Wrapped: FC<P> = (props) => (
    <Suspense fallback={null}>
      <Lazy {...(props as P & {})} />
    </Suspense>
  );
  Wrapped.displayName = `Lazy(${exportName})`;
  return Wrapped;
}

const Content7View = lazySection<SectionComponentPropsMap['content-7']>(
  () => import('@/components/content-7'),
  'Content7View',
);
const ScrollAccordionView = lazySection<SectionComponentPropsMap['scroll-accordion']>(
  () => import('@/components/scroll-accordion'),
  'ScrollAccordionView',
);
const StickySectionView = lazySection<SectionComponentPropsMap['sticky-section']>(
  () => import('@/components/sticky-section'),
  'StickySectionView',
);
const CodeBlockView = lazySection<SectionComponentPropsMap['code-block']>(
  () => import('@/components/code-block'),
  'CodeBlockView',
);
const PremiumCtaView = lazySection<SectionComponentPropsMap['premium-cta']>(
  () => import('@/components/premium-cta'),
  'PremiumCtaView',
);
const FormDemoView = lazySection<SectionComponentPropsMap['form-demo']>(
  () => import('@/components/form-demo'),
  'FormDemoView',
);

export const ComponentRegistry: {
  [K in SectionType]: FC<SectionComponentPropsMap[K]>;
} = {
  'empty-tenant': EmptyTenantView as FC<SectionComponentPropsMap['empty-tenant']>,
  'form-demo': FormDemoView,
  header: HeaderView as FC<SectionComponentPropsMap['header']>,
  footer: FooterView as FC<SectionComponentPropsMap['footer']>,
  'premium-hero': PremiumHeroView as FC<SectionComponentPropsMap['premium-hero']>,
  'premium-cta': PremiumCtaView,
  'sticky-section': StickySectionView,
  'scroll-accordion': ScrollAccordionView,
  'content-7': Content7View,
  'code-block': CodeBlockView,
};
