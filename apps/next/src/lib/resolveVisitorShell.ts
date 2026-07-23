import {
  shouldRenderSiteGlobalHeader,
  type PageConfig,
  type Section,
  type SiteConfig,
} from '@olonjs/core';

export type VisitorShellSections = {
  header: Section | null;
  footer: Section | null;
};

/**
 * Visitor chrome: footer always (when site has one); header gated by page `global-header`
 * (absent ⇒ true; false ⇒ hide). Uses core `shouldRenderSiteGlobalHeader`.
 */
export function resolveVisitorShell(page: PageConfig, site: SiteConfig): VisitorShellSections {
  const header =
    shouldRenderSiteGlobalHeader(page, site) && site.header != null ? (site.header as Section) : null;
  const footer = site.footer != null ? (site.footer as Section) : null;
  return { header, footer };
}
