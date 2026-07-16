export {
  isRecord,
  normalizeSlugSegments,
  resolvePageMatchFromRegistry,
  resolveMenuMainFromHeaderData,
  resolvePageFromRegistry,
  resolveSlugFromPathname,
  type PageRouteMatch,
} from './route-utils';
export {
  resolvePublicPageDocument,
  type ResolvedPublicPageDocument,
  type ResolvePublicPageDocumentInput,
} from './public-page-document';
export {
  buildPageContractHref,
  buildPageManifestHref,
  syncHeadLink,
  syncWebMcpJsonLd,
} from './head-sync';
