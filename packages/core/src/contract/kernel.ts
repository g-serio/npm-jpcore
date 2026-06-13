/**
 * KERNEL: The Base Contract (MTRP)
 * Core is self-contained; structural types live here.
 */
export interface BaseSectionSettings {
  [key: string]: unknown;
}

export interface SectionDataRegistry {}
export interface SectionSettingsRegistry {}

export interface CollectionItemRegistry {}

export interface BaseSection<K extends keyof SectionDataRegistry> {
  id: string;
  type: K;
  data: SectionDataRegistry[K];
  settings?: K extends keyof SectionSettingsRegistry
    ? SectionSettingsRegistry[K]
    : BaseSectionSettings;
}

/** Structural shape used when no tenant has augmented the registries. */
export interface FallbackSection {
  id: string;
  type: string;
  data: Record<string, unknown>;
  settings?: Record<string, unknown>;
}

/** Computed union of all registered section types. */
export type Section =
  keyof SectionDataRegistry extends never
    ? FallbackSection
    : { [K in keyof SectionDataRegistry]: BaseSection<K> }[keyof SectionDataRegistry];

export type SectionType = keyof SectionDataRegistry extends never ? string : keyof SectionDataRegistry;

export interface CollectionItem {
  id: string;
}

export type CollectionType = keyof CollectionItemRegistry extends never ? string : keyof CollectionItemRegistry;

export type CollectionDocument<TItem = CollectionItem> = Record<string, TItem>;

export interface MenuItem {
  label: string;
  href: string;
  icon?: string;
  external?: boolean;
  isCta?: boolean;
  children?: MenuItem[];
}

export interface MenuConfig {
  main?: MenuItem[];
  [key: string]: MenuItem[] | undefined;
}

export interface PageMeta {
  title: string;
  description: string;
}

export interface PageCollectionBinding {
  source: CollectionType;
  paramKey: string;
}

export interface PageConfig {
  id: string;
  slug: string;
  meta: PageMeta;
  sections: Section[];
  collection?: PageCollectionBinding;
  /** When `false`, Core does not render the global header from `site.json` for this page. Omitted = default (show if configured). */
  'global-header'?: boolean;
}

/** Whether the global `site.json` header should be rendered for this page. */
export function shouldRenderSiteGlobalHeader(page: PageConfig, site: SiteConfig): boolean {
  return site.header != null && page['global-header'] !== false;
}

export interface SiteIdentity {
  title: string;
  logoUrl?: string;
}

export interface SiteConfig {
  identity: SiteIdentity;
  header?: Section;
  footer: Section;
}

export interface ThemeTokenMap {
  [key: string]: string;
}

export interface ThemeColors {

  [key: string]: string;
}

export interface ThemeFontFamily {

  [key: string]: string | undefined;
}

export interface ThemeTypography {
  fontFamily: ThemeFontFamily;
}

export interface ThemeBorderRadius {

  [key: string]: string;
}

export interface ThemeTokens {
  colors: ThemeColors;
  typography: ThemeTypography;
  borderRadius: ThemeBorderRadius;
}

export interface ThemeConfig {
  name: string;
  tokens: ThemeTokens;
}

/**
 * PROJECT STATE (The Universal Data Bundle)
 * Moved to Kernel to serve as SSOT for Engine and Persistence.
 */
export interface ProjectState {
  page: PageConfig;
  site: SiteConfig;
  menu: MenuConfig;
  theme: ThemeConfig;
  collections?: Record<string, CollectionDocument<unknown>>;
}

export interface PageRendererProps {
  pageConfig: PageConfig;
  siteConfig: SiteConfig;
  menuConfig: MenuConfig;
  selectedId?: string | null;
}
