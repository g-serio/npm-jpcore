import type { AddSectionConfig } from '@olonjs/core';

const addableSectionTypes = [
  'empty-tenant',
  'form-demo',
  'premium-hero',
  'sticky-section',
  'premium-cta',
  'scroll-accordion',
  'content-7',
  'code-block',
] as const;

const sectionTypeLabels: Record<string, string> = {
  'empty-tenant': 'Empty Tenant',
  'form-demo': 'Form Demo',
  'premium-hero': 'Premium hero',
  'sticky-section': 'Sticky section',
  'premium-cta': 'Premium CTA',
  'scroll-accordion': 'Scroll accordion',
  'content-7': 'Content grid (3-up)',
  'code-block': 'Code block (Shiki)',
};

function getDefaultSectionData(type: string): Record<string, unknown> {
  switch (type) {
    case 'empty-tenant':
      return {
        title: 'Your tenant is empty.',
        description: 'Create your first page to start building your site.',
      };
    case 'form-demo':
      return {
        title: 'Contattaci',
        description: 'Compila il modulo e ti risponderemo al più presto.',
        recipientEmail: '',
        submitLabel: 'Invia',
        successMessage: 'Richiesta inviata con successo.',
      };
    case 'premium-hero':
      return {
        backgroundImage: {
          url: 'https://picsum.photos/seed/proculthero/1920/1080',
          alt: 'Hero background',
        },
        badgeText: 'Now in Public Beta',
        primaryTitle: 'Build Products',
        secondaryTitle: 'People Love',
        subtitle:
          'The modern platform for teams who ship fast. Streamlined workflows, powerful collaboration, and insights that matter.',
        primaryCta: { label: 'Get Started Free', href: '#', variant: 'primary' },
        secondaryCta: { label: 'Watch Demo', href: '#', variant: 'secondary' },
        socialProofPrefix: 'Loved by',
        socialProofCount: '12,000+ teams',
        avatars: [
          { id: 'av-1', initials: 'JD', preset: 'amber' },
          { id: 'av-2', initials: 'SK', preset: 'emerald' },
          { id: 'av-3', initials: 'AL', preset: 'blue' },
        ],
      };
    case 'sticky-section':
      return {
        eyebrow: '',
        heading: '',
        description: '',
        projects: [
          {
            id: 'blocks',
            name: 'Blocks',
            tagline: 'Production-ready marketing sections',
            description:
              'Drop-in hero, pricing, bento, and CTA sections built with the same patterns you already use. Install with the shadcn CLI, tweak in your codebase, and ship without rebuilding layouts from scratch.',
            stars: '100+',
            starsLabel: 'sections',
            contributors: 'CLI',
            contributorsLabel: 'install',
            exploreUrl: '/patterns',
            image: {
              url: 'https://picsum.photos/seed/procultblocks/1200/750',
              alt: 'Anteprima sezione Blocks',
            },
            iconVariant: 'blocks',
          },
          {
            id: 'full-stack-blocks',
            name: 'Full Stack Blocks',
            tagline: 'End-to-end patterns, not just UI chrome',
            description:
              'Patterns that include app routes, server actions, data shapes, and sensible defaults—so you start from a working feature, not an empty component.',
            stars: '15+',
            starsLabel: 'full-stack examples',
            contributors: 'Next.js',
            contributorsLabel: 'App Router',
            exploreUrl: '/blocks',
            image: {
              url: 'https://picsum.photos/seed/procultstack/1200/750',
              alt: 'Anteprima Full Stack Blocks',
            },
            iconVariant: 'layers',
          },
        ],
      };
    case 'premium-cta':
      return {
        headingLight: 'Transform your digital',
        headingBold: 'experience today',
        body: 'Join thousands of innovators who are already building the future with our cutting-edge platform.',
        primaryCta: { label: 'Get started', href: '#', variant: 'primary' },
        secondaryCta: { label: 'Learn more', href: '#', variant: 'secondary' },
        socialProofLine: '10,000+ companies trust our platform',
        socialProofHighlight: '10k+',
      };
    case 'scroll-accordion':
      return {
        eyebrow: '',
        heading: '',
        description: '',
        items: [
          {
            id: 'acc-1',
            number: 'S/001',
            title: 'Advisory',
            description:
              'Gain strategic insights from our fractional CTOs, benefit from comprehensive technical reviews, and receive expert guidance on technology strategy to drive your business forward.',
            cta: { label: 'See our services', href: '#', variant: 'primary' },
          },
          {
            id: 'acc-2',
            number: 'S/002',
            title: 'Product development',
            description:
              'Bring market-ready products to life with prototypes, MVPs, SaaS, web, and mobile applications—managed from planning and design through coding, testing, and ongoing maintenance.',
            cta: { label: 'See our services', href: '#', variant: 'primary' },
          },
          {
            id: 'acc-3',
            number: 'S/003',
            title: 'Cloud infrastructure',
            description:
              'Design and implement scalable cloud architectures on AWS, GCP, or Azure. Migration, optimization, DevOps automation, and ongoing infrastructure management for maximum performance.',
            cta: { label: 'See our services', href: '#', variant: 'primary' },
          },
        ],
      };
    case 'content-7':
      return {
        headingLead: 'Building the next generation of',
        headingEmphasis: 'AI-powered Marketing Tools',
        description: '',
        cards: [
          {
            id: 'content7-card-1',
            tileVariant: 'elevated',
            image: {
              url: 'https://raw.githubusercontent.com/tailark/assets/refs/heads/main/time_djv8te.webp',
              alt: 'Visual intelligence representation',
            },
            eyebrow: 'Not a Bad Story',
            copyLead: 'Our platform',
            copyEmphasis: 'integrates text, image, and audio processing',
            copyTrail: 'into a unified framework.',
            readLink: {
              label: 'Read more',
              href: 'https://raw.githubusercontent.com/tailark/assets/refs/heads/main/ai-human-2_uo6bxc.jpg',
            },
          },
          {
            id: 'content7-card-2',
            tileVariant: 'elevated',
            image: {
              url: 'https://raw.githubusercontent.com/tailark/assets/refs/heads/main/dots-2_kmiukp.webp',
              alt: 'Multimodal learning visualization',
            },
            eyebrow: 'Made 3M in 2 years',
            copyLead: 'Our platform',
            copyEmphasis: 'integrates text, image, and audio processing',
            copyTrail: 'into a unified framework.',
            readLink: {
              label: 'Read more',
              href: 'https://raw.githubusercontent.com/tailark/assets/refs/heads/main/ai-human-2_uo6bxc.jpg',
            },
          },
          {
            id: 'content7-card-3',
            tileVariant: 'surface',
            image: {
              url: 'https://raw.githubusercontent.com/tailark/assets/refs/heads/main/dna_lp2xey.webp',
              alt: 'Multimodal learning visualization',
            },
            eyebrow: 'Raised 10M',
            copyLead: 'Our platform',
            copyEmphasis: 'integrates text, image, and audio processing',
            copyTrail: 'into a unified framework.',
            readLink: {
              label: 'Read more',
              href: 'https://raw.githubusercontent.com/tailark/assets/refs/heads/main/ai-human-2_uo6bxc.jpg',
            },
          },
        ],
      };
    case 'code-block':
      return {
        eyebrow: '',
        heading: '',
        description: '',
        columns: [
          {
            id: 'col-1',
            tabs: [
              {
                id: 'tab-app',
                filename: 'App.tsx',
                language: 'tsx',
                code: 'export function App() {\n  return <div className="p-4">Hello OlonJS</div>;\n}\n',
              },
            ],
          },
          {
            id: 'col-2',
            tabs: [
              {
                id: 'tab-config',
                filename: 'vite.config.ts',
                language: 'typescript',
                code: "import { defineConfig } from 'vite';\nimport react from '@vitejs/plugin-react';\n\nexport default defineConfig({ plugins: [react()] });\n",
              },
            ],
          },
        ],
      };
    default:
      return {};
  }
}

export const addSectionConfig: AddSectionConfig = {
  addableSectionTypes: [...addableSectionTypes],
  sectionTypeLabels,
  getDefaultSectionData,
};
