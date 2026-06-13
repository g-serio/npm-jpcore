import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { buildPageContract, buildPageManifest, buildSiteManifest } from './index';

describe('webmcp contracts', () => {
  const HeroSchema = z.object({
    title: z.string().describe('ui:text'),
    ctas: z.array(
      z.object({
        id: z.string().optional(),
        label: z.string(),
        href: z.string(),
      })
    ).optional(),
  });

  const FeatureGridSchema = z.object({
    sectionTitle: z.string(),
  });

  const HeaderSchema = z.object({
    logoText: z.string(),
  });

  const ContactFormSchema = z.object({
    title: z.string(),
    submitLabel: z.string(),
  });

  const ContactFormSubmissionSchema = z.object({
    name: z.string().min(1).describe('Full name'),
    email: z.string().email().describe('Email address'),
    notes: z.string().max(1000).optional().describe('Additional notes'),
  });

  it('builds a page contract with only the schemas used on the page', () => {
    const contract = buildPageContract({
      slug: 'home',
      pageConfig: {
        id: 'home-page',
        slug: 'home',
        meta: {
          title: 'Home',
          description: 'Landing page',
        },
        sections: [{ id: 'hero-main', type: 'hero', data: { title: 'Start' } }],
      },
      schemas: {
        hero: HeroSchema,
        'feature-grid': FeatureGridSchema,
        header: HeaderSchema,
      },
      siteConfig: {
        identity: { title: 'Site' },
        header: { id: 'global-header', type: 'header', data: { logoText: 'Olon' } },
      },
    });

    expect(contract.slug).toBe('home');
    expect(contract.sectionTypes).toEqual(['header', 'hero']);
    expect(Object.keys(contract.sectionSchemas)).toEqual(['header', 'hero']);
    expect(contract.sectionInstances).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'global-header', type: 'header', scope: 'global' }),
        expect.objectContaining({ id: 'hero-main', type: 'hero', scope: 'local' }),
      ])
    );
    expect(contract.tools).toEqual([
      expect.objectContaining({
        name: 'update-section',
        inputSchema: expect.objectContaining({
          type: 'object',
          required: ['sectionId'],
        }),
      }),
      expect.objectContaining({
        name: 'save',
        inputSchema: expect.objectContaining({
          type: 'object',
        }),
      }),
    ]);
  });

  it('builds a page-scoped manifest for the active page', () => {
    const manifest = buildPageManifest({
      slug: 'design-system',
      pageConfig: {
        id: 'design-system-page',
        slug: 'design-system',
        meta: { title: 'Design System', description: 'Tokens' },
        sections: [{ id: 'ds-main', type: 'feature-grid', data: { sectionTitle: 'Scale' } }],
      },
      schemas: {
        'feature-grid': FeatureGridSchema,
        header: HeaderSchema,
      },
      siteConfig: {
        identity: { title: 'Site' },
        header: { id: 'global-header', type: 'header', data: { logoText: 'Olon' } },
      },
    });

    expect(manifest.slug).toBe('design-system');
    expect(manifest.contractHref).toBe('/schemas/design-system.schema.json');
    expect(manifest.tools).toEqual([
      expect.objectContaining({ name: 'update-section' }),
      expect.objectContaining({ name: 'save' }),
    ]);
    expect(manifest.transport).toMatchObject({
      kind: 'window-message',
      requestType: 'olonjs:webmcp:tool-call',
      resultType: 'olonjs:webmcp:tool-result',
    });
  });

  it('builds a site manifest index with per-page manifest references', () => {
    const manifest = buildSiteManifest({
      pages: {
        home: {
          id: 'home-page',
          slug: 'home',
          meta: { title: 'Home', description: 'Landing page' },
          sections: [{ id: 'hero-main', type: 'hero', data: { title: 'Start' } }],
        },
        'design-system': {
          id: 'design-system-page',
          slug: 'design-system',
          meta: { title: 'Design System', description: 'Tokens' },
          sections: [{ id: 'ds-main', type: 'feature-grid', data: { sectionTitle: 'Scale' } }],
        },
      },
      schemas: {
        hero: HeroSchema,
        'feature-grid': FeatureGridSchema,
      },
      siteConfig: {
        identity: { title: 'Site' },
      },
    });

    expect(manifest.kind).toBe('olonjs-mcp-manifest-index');
    expect(manifest.pages).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          slug: 'home',
          manifestHref: '/mcp-manifests/home.json',
          contractHref: '/schemas/home.schema.json',
        }),
        expect.objectContaining({
          slug: 'design-system',
          manifestHref: '/mcp-manifests/design-system.json',
          contractHref: '/schemas/design-system.schema.json',
        }),
      ])
    );
    expect(manifest.pages.every((page) => Array.isArray(page.sectionTypes))).toBe(true);
  });

  it('emits sectionSubmissionSchemas for sections on the page that have a registered submission schema', () => {
    const contract = buildPageContract({
      slug: 'contact',
      pageConfig: {
        id: 'contact-page',
        slug: 'contact',
        meta: { title: 'Contact', description: 'Get in touch' },
        sections: [
          {
            id: 'cf-main',
            type: 'contact-form',
            data: { title: 'Say hi', submitLabel: 'Send' },
          },
        ],
      },
      schemas: { 'contact-form': ContactFormSchema },
      submissionSchemas: { 'contact-form': ContactFormSubmissionSchema },
      siteConfig: { identity: { title: 'Site' } },
    });

    expect(contract.sectionSubmissionSchemas).toBeDefined();
    expect(Object.keys(contract.sectionSubmissionSchemas!)).toEqual(['contact-form']);

    const submission = contract.sectionSubmissionSchemas!['contact-form'];
    expect(submission).toMatchObject({
      type: 'object',
      properties: expect.objectContaining({
        name: expect.objectContaining({ type: 'string', description: 'Full name' }),
        email: expect.objectContaining({ type: 'string', description: 'Email address' }),
        notes: expect.objectContaining({ type: 'string', description: 'Additional notes' }),
      }),
    });
    expect(submission.required).toEqual(expect.arrayContaining(['name', 'email']));
    expect((submission.required as string[]) ?? []).not.toContain('notes');
  });

  it('omits sectionSubmissionSchemas entirely when no section on the page has one registered', () => {
    const contract = buildPageContract({
      slug: 'home',
      pageConfig: {
        id: 'home-page',
        slug: 'home',
        meta: { title: 'Home', description: 'Landing page' },
        sections: [{ id: 'hero-main', type: 'hero', data: { title: 'Start' } }],
      },
      schemas: { hero: HeroSchema },
      submissionSchemas: { 'contact-form': ContactFormSubmissionSchema },
      siteConfig: { identity: { title: 'Site' } },
    });

    expect(contract.sectionSubmissionSchemas).toBeUndefined();
  });

  it('keeps UI-config sectionSchemas and submission sectionSubmissionSchemas separate for the same section type', () => {
    const contract = buildPageContract({
      slug: 'contact',
      pageConfig: {
        id: 'contact-page',
        slug: 'contact',
        meta: { title: 'Contact', description: 'Get in touch' },
        sections: [
          {
            id: 'cf-main',
            type: 'contact-form',
            data: { title: 'Say hi', submitLabel: 'Send' },
          },
        ],
      },
      schemas: { 'contact-form': ContactFormSchema },
      submissionSchemas: { 'contact-form': ContactFormSubmissionSchema },
      siteConfig: { identity: { title: 'Site' } },
    });

    expect(Object.keys(contract.sectionSchemas)).toEqual(['contact-form']);
    expect(Object.keys(contract.sectionSubmissionSchemas!)).toEqual(['contact-form']);

    const uiProps = (contract.sectionSchemas['contact-form'] as { properties: Record<string, unknown> }).properties;
    const submitProps = (contract.sectionSubmissionSchemas!['contact-form'] as { properties: Record<string, unknown> }).properties;

    expect(Object.keys(uiProps)).toEqual(['title', 'submitLabel']);
    expect(Object.keys(submitProps)).toEqual(['name', 'email', 'notes']);
  });
});
