import {
  buildPageContractHref,
  buildPageManifestHref,
} from '../../contract/webmcp-contracts';

export function syncHeadLink(rel: string, href: string) {
  if (typeof document === 'undefined') return;
  const selector = `link[rel="${rel}"]`;
  let link = document.head.querySelector(selector) as HTMLLinkElement | null;
  if (!link) {
    link = document.createElement('link');
    link.rel = rel;
    document.head.appendChild(link);
  }
  link.href = href;
}

export function syncWebMcpJsonLd(title: string, description: string, url: string) {
  if (typeof document === 'undefined') return;
  const scriptId = 'olonjs-webmcp-jsonld';
  let script = document.getElementById(scriptId) as HTMLScriptElement | null;
  if (!script) {
    script = document.createElement('script');
    script.type = 'application/ld+json';
    script.id = scriptId;
    document.head.appendChild(script);
  }
  script.textContent = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: title,
    description,
    url,
    'subjectOf': {
    '@type': 'CreativeWork',
    'additionalType': 'mcp-manifest',
    'url': '/mcp-manifests/home.json'
  }
  });
}

export { buildPageContractHref, buildPageManifestHref };
