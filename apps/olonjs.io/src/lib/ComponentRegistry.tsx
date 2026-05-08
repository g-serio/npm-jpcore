import type { FC } from 'react';
import type { SectionType } from '@/types';
import type { SectionComponentPropsMap } from '@/types';
import { EmptyTenantView } from '@/components/empty-tenant';
import { FooterView } from '@/components/footer';
import { FormDemoView } from '@/components/form-demo';
import { HeaderView } from '@/components/header';
import { PremiumCtaView } from '@/components/premium-cta';
import { PremiumHeroView } from '@/components/premium-hero';
import { ScrollAccordionView } from '@/components/scroll-accordion';
import { StickySectionView } from '@/components/sticky-section';
import { Content7View } from '@/components/content-7';
import { CodeBlockView } from '@/components/code-block';

export const ComponentRegistry: {
  [K in SectionType]: FC<SectionComponentPropsMap[K]>;
} = {
  'empty-tenant': EmptyTenantView as FC<SectionComponentPropsMap['empty-tenant']>,
  'form-demo': FormDemoView as FC<SectionComponentPropsMap['form-demo']>,
  header: HeaderView as FC<SectionComponentPropsMap['header']>,
  footer: FooterView as FC<SectionComponentPropsMap['footer']>,
  'premium-hero': PremiumHeroView as FC<SectionComponentPropsMap['premium-hero']>,
  'premium-cta': PremiumCtaView as FC<SectionComponentPropsMap['premium-cta']>,
  'sticky-section': StickySectionView as FC<SectionComponentPropsMap['sticky-section']>,
  'scroll-accordion': ScrollAccordionView as FC<SectionComponentPropsMap['scroll-accordion']>,
  'content-7': Content7View as FC<SectionComponentPropsMap['content-7']>,
  'code-block': CodeBlockView as FC<SectionComponentPropsMap['code-block']>,
};
