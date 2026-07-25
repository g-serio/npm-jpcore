#!/bin/bash
set -e

# Always operate in the directory that contains this script (same contract as Vite / Inkwell Next).
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Andrew Linh — Portfolio & Blog (OlonJS v1.6 tenant-gen — Next harness)
# Neo-brutalist · dark-first · terminal green
# Typography: Instrument Sans + Instrument Serif + JetBrains Mono
# Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
# Place/copy this script into a scaffolded Next tenant root (or ship in DNA).
# No ThemeProvider — light/dark via document.documentElement.dataset.theme
# =============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           ANDREW LINH — portfolio & editorial site           ║"
echo "║     systems architect · technical writer · Next harness      ║"
echo "║     CWD = script dir ($(pwd))                                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
# -----------------------------------------------------------------------------
# 0. SHADCN/UI INIT
# -----------------------------------------------------------------------------
echo "-- Step 0: shadcn/ui init..."
npm install class-variance-authority clsx tailwind-merge lucide-react
npm install react-markdown remark-gfm rehype-sanitize motion
npx shadcn@latest init --yes --style new-york --base-color slate 2>/dev/null || true
npx shadcn@latest add --yes --overwrite \
  button card badge separator avatar table tabs accordion dialog sheet tooltip \
  navigation-menu dropdown-menu hover-card breadcrumb skeleton progress input \
  label textarea select checkbox switch toggle toggle-group scroll-area aspect-ratio
echo "   shadcn/ui components installed"

# -----------------------------------------------------------------------------
# PREFLIGHT — Next App Router layout must exist
# -----------------------------------------------------------------------------
echo "-- Preflight: checking app/layout.tsx..."
if [[ -f app/layout.tsx ]]; then
  echo "   app/layout.tsx found"
else
  echo "!! app/layout.tsx NOT found — this script cds to its own directory; place it in the Next tenant root"
  exit 1
fi

# -----------------------------------------------------------------------------
# CLEAN DNA DEMO — remove marketplace seed capsules before SystemsArchitect write
# (same contract as Vite SA + Next public sync paths — leftover imports break build)
# -----------------------------------------------------------------------------
echo "-- Cleaning demo capsules / collections / pages..."
rm -rf \
  src/components/books-list \
  src/components/authors-list \
  src/components/book-detail \
  src/components/form-demo \
  src/components/empty-tenant \
  src/collections/autori \
  src/collections/libri \
  src/data/collections/autori \
  src/data/collections/libri \
  src/data/pages/authors \
  src/data/pages/libri \
  src/data/pages/work \
  src/data/pages/blog \
  public/pages \
  public/collections
rm -f \
  src/data/pages/home.json \
  src/data/pages/authors.json \
  src/data/pages/libri.json \
  src/data/pages/form.json \
  src/data/pages/about.json \
  src/data/pages/work.json \
  src/data/pages/blog.json \
  src/data/pages/contact.json \
  public/config/site.json

# Drop books-list special-case so deleted capsules cannot break the visitor RSC path.
echo "-- Resetting VisitorSection to registry-only..."
mkdir -p src/lib
cat > src/lib/VisitorSection.tsx << 'EOF'
import type { FC } from 'react';
import type { Section, SectionType } from '@/types';
import { ComponentRegistry } from '@/lib/ComponentRegistry';

export type VisitorSectionExtras = {
  authorId?: string | null;
  page?: number;
  pathname?: string;
};

/** Render a resolved page section via the tenant ComponentRegistry (RSC path). */
export function VisitorSection({
  section,
}: {
  section: Section;
  extras?: VisitorSectionExtras;
}) {
  const type = section.type as SectionType;
  const Comp = ComponentRegistry[type];
  if (!Comp) {
    return (
      <section className="px-6 py-8 text-muted-foreground">
        Unknown section type: {String(section.type)}
      </section>
    );
  }

  const View = Comp as FC<{ data: unknown; settings?: unknown }>;
  return <View data={section.data} settings={section.settings} />;
}
EOF

# DNA catch-all imports EmptyTenantView — drop it after rm of that capsule.
if [[ -f 'app/[[...slug]]/page.tsx' ]]; then
  echo "-- Patching app/[[...slug]]/page.tsx empty fallback..."
  python3 - <<'PY'
from pathlib import Path
p = Path("app/[[...slug]]/page.tsx")
src = p.read_text()
capsule = "empty" + "-tenant"
src = src.replace(f"import {{ EmptyTenantView }} from '@/components/{capsule}';\n", "")
old = "  if (result.kind === 'empty') {\n    return <EmptyTenantView />;\n  }"
new = """  if (result.kind === 'empty') {
    return (
      <main className="mx-auto max-w-3xl px-8 py-24">
        <h1 className="text-2xl font-bold">Your tenant is empty.</h1>
        <p className="mt-2 text-muted-foreground">Create your first page.</p>
      </main>
    );
  }"""
if old not in src:
    raise SystemExit("EmptyTenantView empty-branch not found in page.tsx")
p.write_text(src.replace(old, new))
print("   page.tsx empty fallback inlined")
PY
fi

mkdir -p \
  src/components/{header,footer,home-hero,featured-projects,recent-posts,bio-band,cta-band,page-hero,about-story,skills-stack,philosophy,projects-list,project-detail,posts-list,post-detail,contact-form} \
  src/collections/{projects,posts} \
  src/data/collections/{projects,posts} \
  src/data/pages/{work,blog} \
  src/data/config src/lib

if [ -f src/lib/env/tenantEnv.ts ]; then
  sed -i "s/TENANT_ID = 'alpha'/TENANT_ID = 'al'/g" src/lib/env/tenantEnv.ts || true
fi

if [ -f src/lib/env/tenantEnv.ts ]; then
  sed -i "s/TENANT_ID = 'alpha'/TENANT_ID = 'al'/g" src/lib/env/tenantEnv.ts || true
  sed -i "s/TENANT_ID = 'next'/TENANT_ID = 'al'/g" src/lib/env/tenantEnv.ts || true
fi

# =============================================================================
# app/globals.css — fonts first line, semantic bridge, light mode, TOCC
# =============================================================================
echo "-- Writing app/globals.css..."
cat > app/globals.css << 'EOF'
@import url('https://fonts.googleapis.com/css2?family=Instrument+Sans:ital,wght@0,400;0,500;0,600;0,700;1,400&family=Instrument+Serif:ital@0;1&family=JetBrains+Mono:wght@400;500;600;700&display=swap');
@import "tailwindcss";
@source "../src/**/*.tsx";

@theme {
  --color-background:           var(--background);
  --color-foreground:           var(--foreground);
  --color-card:                 var(--card);
  --color-card-foreground:      var(--card-foreground);
  --color-primary:              var(--primary);
  --color-primary-foreground:   var(--primary-foreground);
  --color-secondary:            var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted:                var(--muted);
  --color-muted-foreground:     var(--muted-foreground);
  --color-accent:               var(--accent);
  --color-border:               var(--border);
  --radius-lg:                  var(--theme-radius-lg);
  --radius-md:                  var(--theme-radius-md);
  --radius-sm:                  var(--theme-radius-sm);
  --font-primary: var(--theme-font-primary);
  --font-mono:    var(--theme-font-mono);
  --font-display: var(--theme-font-display);
}

:root {
  --background:           var(--theme-colors-background);
  --foreground:           var(--theme-colors-foreground);
  --card:                 var(--theme-colors-card);
  --card-foreground:      var(--theme-colors-card-foreground);
  --elevated:             var(--theme-colors-elevated);
  --overlay:              var(--theme-colors-overlay);
  --primary:              var(--theme-colors-primary);
  --primary-foreground:   var(--theme-colors-primary-foreground);
  --primary-light:        var(--theme-colors-primary-light);
  --primary-dark:         var(--theme-colors-primary-dark);
  --secondary:            var(--theme-colors-secondary);
  --secondary-foreground: var(--theme-colors-secondary-foreground);
  --muted:                var(--theme-colors-muted);
  --muted-foreground:     var(--theme-colors-muted-foreground);
  --accent:               var(--theme-colors-accent);
  --accent-foreground:    var(--theme-colors-accent-foreground);
  --border:               var(--theme-colors-border);
  --border-strong:        var(--theme-colors-border-strong);
  --input:                var(--theme-colors-input);
  --ring:                 var(--theme-colors-ring);
  --destructive:          var(--theme-colors-destructive);
  --destructive-foreground: var(--theme-colors-destructive-foreground);
  --success:              var(--theme-colors-success);
  --success-foreground:   var(--theme-colors-success-foreground);
  --warning:              var(--theme-colors-warning);
  --warning-foreground:   var(--theme-colors-warning-foreground);
  --info:                 var(--theme-colors-info);
  --info-foreground:      var(--theme-colors-info-foreground);
  --radius:               var(--theme-radius-lg);
  --demo-surface:         color-mix(in oklch, var(--card) 86%, var(--background));
  --demo-surface-soft:    color-mix(in oklch, var(--card) 72%, var(--background));
  --demo-surface-strong:  color-mix(in oklch, var(--background) 82%, black);
  --demo-surface-deep:    color-mix(in oklch, var(--background) 70%, black);
  --demo-border-soft:     color-mix(in oklch, var(--foreground) 8%, transparent);
  --demo-border-strong:   color-mix(in oklch, var(--primary) 24%, transparent);
  --demo-accent-soft:     color-mix(in oklch, var(--primary) 10%, transparent);
  --demo-accent-strong:   color-mix(in oklch, var(--primary) 18%, transparent);
  --demo-text-soft:       color-mix(in oklch, var(--foreground) 88%, var(--muted-foreground));
  --demo-text-faint:      color-mix(in oklch, var(--muted-foreground) 72%, transparent);
}

[data-theme="light"] {
  --background:           var(--theme-modes-light-colors-background);
  --foreground:           var(--theme-modes-light-colors-foreground);
  --card:                 var(--theme-modes-light-colors-card);
  --card-foreground:      var(--theme-modes-light-colors-card-foreground);
  --elevated:             var(--theme-modes-light-colors-elevated);
  --overlay:              var(--theme-modes-light-colors-overlay);
  --primary:              var(--theme-modes-light-colors-primary);
  --primary-foreground:   var(--theme-modes-light-colors-primary-foreground);
  --primary-light:        var(--theme-modes-light-colors-primary-light);
  --primary-dark:         var(--theme-modes-light-colors-primary-dark);
  --secondary:            var(--theme-modes-light-colors-secondary);
  --secondary-foreground: var(--theme-modes-light-colors-secondary-foreground);
  --muted:                var(--theme-modes-light-colors-muted);
  --muted-foreground:     var(--theme-modes-light-colors-muted-foreground);
  --accent:               var(--theme-modes-light-colors-accent);
  --accent-foreground:    var(--theme-modes-light-colors-accent-foreground);
  --border:               var(--theme-modes-light-colors-border);
  --border-strong:        var(--theme-modes-light-colors-border-strong);
  --input:                var(--theme-modes-light-colors-input);
  --ring:                 var(--theme-modes-light-colors-ring);
  --destructive:          var(--theme-modes-light-colors-destructive);
  --destructive-foreground: var(--theme-modes-light-colors-destructive-foreground);
  --success:              var(--theme-modes-light-colors-success);
  --success-foreground:   var(--theme-modes-light-colors-success-foreground);
  --warning:              var(--theme-modes-light-colors-warning);
  --warning-foreground:   var(--theme-modes-light-colors-warning-foreground);
  --info:                 var(--theme-modes-light-colors-info);
  --info-foreground:      var(--theme-modes-light-colors-info-foreground);
}

@layer base {
  * { border-color: var(--border); }
  body {
    background-color: var(--background);
    color: var(--foreground);
    font-family: var(--font-primary);
    line-height: 1.7;
    overflow-x: hidden;
    @apply antialiased;
  }
}
.font-display { font-family: var(--font-display, var(--font-primary)); }
html { scroll-behavior: smooth; }
@keyframes jp-fadeUp { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
.jp-animate-in { opacity: 0; animation: jp-fadeUp 0.7s ease forwards; }
.jp-d1 { animation-delay: 0.1s; }
.jp-d2 { animation-delay: 0.2s; }
.jp-d3 { animation-delay: 0.3s; }
.jp-d4 { animation-delay: 0.4s; }
@keyframes jp-pulseDot { 0%, 100% { opacity: 1; transform: scale(1); } 50% { opacity: 0.5; transform: scale(0.85); } }
.jp-pulse-dot { animation: jp-pulseDot 2s ease infinite; }
[data-jp-section-overlay] { position: absolute; inset: 0; z-index: 9999; pointer-events: none; border: 2px solid transparent; transition: border-color 0.15s, background-color 0.15s; }
[data-section-id]:hover [data-jp-section-overlay] { border: 2px dashed color-mix(in oklch, var(--primary) 50%, transparent); background-color: color-mix(in oklch, var(--primary) 6%, transparent); }
[data-section-id][data-jp-selected] [data-jp-section-overlay] { border: 2px solid var(--primary); background-color: color-mix(in oklch, var(--primary) 10%, transparent); }
[data-jp-section-overlay] > div { position: absolute; top: 0; right: 0; padding: 0.2rem 0.55rem; font-size: 9px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.1em; background: var(--primary); color: #fff; opacity: 0; transition: opacity 0.15s; }
[data-section-id]:hover [data-jp-section-overlay] > div,
[data-section-id][data-jp-selected] [data-jp-section-overlay] > div { opacity: 1; }
EOF

# =============================================================================
# COLLECTIONS + IconResolver + CollectionRegistry
# =============================================================================
echo "-- Writing collections..."
cat > src/collections/projects/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseCollectionItem, ImageSelectionSchema } from '@olonjs/core';

export const ProjectSchema = BaseCollectionItem.extend({
  title: z.string().describe('ui:text'),
  subtitle: z.string().describe('ui:text'),
  year: z.number().describe('ui:number'),
  role: z.string().describe('ui:text'),
  context: z.string().describe('ui:textarea'),
  problem: z.string().describe('ui:textarea'),
  architecture: z.string().describe('ui:textarea'),
  result: z.string().describe('ui:textarea'),
  stack: z.array(z.string()).default([]).describe('ui:list'),
  image: ImageSelectionSchema.optional(),
  tags: z.array(z.string()).default([]).describe('ui:list'),
  featured: z.boolean().default(false).describe('ui:checkbox'),
});
export const ProjectsCollectionSchema = z.record(z.string(), ProjectSchema);
EOF
cat > src/collections/projects/types.ts << 'EOF'
import { z } from 'zod';
import { ProjectSchema, ProjectsCollectionSchema } from './schema';
export type Project = z.infer<typeof ProjectSchema>;
export type ProjectsCollection = z.infer<typeof ProjectsCollectionSchema>;
EOF
cat > src/collections/projects/index.ts << 'EOF'
export { ProjectSchema, ProjectsCollectionSchema } from './schema';
export type { Project, ProjectsCollection } from './types';
EOF

cat > src/collections/posts/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseCollectionItem, ImageSelectionSchema } from '@olonjs/core';
export const PostSchema = BaseCollectionItem.extend({
  title: z.string().describe('ui:text'),
  dek: z.string().describe('ui:textarea'),
  date: z.string().describe('ui:text'),
  readingTime: z.string().describe('ui:text'),
  tags: z.array(z.string()).default([]).describe('ui:list'),
  body: z.string().describe('ui:textarea'),
  image: ImageSelectionSchema.optional(),
});
export const PostsCollectionSchema = z.record(z.string(), PostSchema);
EOF
cat > src/collections/posts/types.ts << 'EOF'
import { z } from 'zod';
import { PostSchema, PostsCollectionSchema } from './schema';
export type Post = z.infer<typeof PostSchema>;
export type PostsCollection = z.infer<typeof PostsCollectionSchema>;
EOF
cat > src/collections/posts/index.ts << 'EOF'
export { PostSchema, PostsCollectionSchema } from './schema';
export type { Post, PostsCollection } from './types';
EOF

cat > src/lib/CollectionRegistry.ts << 'EOF'
import { ProjectsCollectionSchema } from '@/collections/projects';
import { PostsCollectionSchema } from '@/collections/posts';
export const CollectionRegistry = {
  projects: ProjectsCollectionSchema,
  posts: PostsCollectionSchema,
} as const;
export type CollectionType = keyof typeof CollectionRegistry;
EOF

cat > src/lib/IconResolver.tsx << 'EOF'
import React from 'react';
import type { LucideIcon } from 'lucide-react';
import {
  ArrowRight, Boxes, Braces, Cloud, Code2, Cpu, Database, FileJson, GitBranch,
  Github, Linkedin, Mail, Menu, Moon, Rss, Server, Shield, Sun, Terminal, Workflow,
} from 'lucide-react';

export const iconMap: Record<string, LucideIcon> = {
  'arrow-right': ArrowRight, boxes: Boxes, braces: Braces, cloud: Cloud, code: Code2,
  cpu: Cpu, database: Database, 'file-json': FileJson, 'git-branch': GitBranch,
  github: Github, linkedin: Linkedin, mail: Mail, menu: Menu, moon: Moon, rss: Rss,
  server: Server, shield: Shield, sun: Sun, terminal: Terminal, workflow: Workflow,
};
export type IconName = keyof typeof iconMap;
export function isIconName(s: string): s is IconName { return s in iconMap; }
export const Icon: React.FC<{ name: string; size?: number; className?: string }> = ({ name, size = 20, className }) => {
  const C = isIconName(name) ? iconMap[name] : undefined;
  if (!C) return null;
  return <C size={size} className={className} />;
};
EOF

# =============================================================================
# CAPSULES — header / footer / home / about / work / blog / contact
# (Views use string concat instead of template literals for heredoc safety)
# =============================================================================
echo "-- Writing capsule: header..."
cat > src/components/header/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';
const HeaderMenuItemSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  isCta: z.boolean().optional().describe('ui:checkbox'),
});
export const HeaderSchema = BaseSectionData.extend({
  logoText: z.string().describe('ui:text'),
  logoHighlight: z.string().optional().describe('ui:text'),
  announcement: z.string().optional().describe('ui:text'),
  menu: z.array(HeaderMenuItemSchema).optional().describe('ui:list'),
});
EOF
cat > src/components/header/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { HeaderSchema } from './schema';
export type HeaderData = z.infer<typeof HeaderSchema>;
export type HeaderSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/header/View.tsx << 'EOF'
'use client';

// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Button } from '@/components/ui/button';
import { NavigationMenu, NavigationMenuItem, NavigationMenuLink, NavigationMenuList } from '@/components/ui/navigation-menu';
import { Sheet, SheetClose, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { Menu, Moon, Sun } from 'lucide-react';
import type { HeaderData, HeaderSettings } from './types';

export const Header: React.FC<{ data: HeaderData; settings: HeaderSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];
  const [theme, setTheme] = React.useState<'light' | 'dark'>(() => {
    if (typeof document === 'undefined') return 'dark';
    return (document.documentElement.dataset.theme as 'light' | 'dark') || 'dark';
  });
  const toggleTheme = () => {
    const next = theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    setTheme(next);
  };
  return (
    <header style={{ '--local-bg': 'color-mix(in oklch, var(--background) 90%, transparent)', '--local-text': 'var(--foreground)', '--local-border': 'var(--border)', '--local-surface': 'color-mix(in oklch, var(--card) 88%, transparent)', '--local-primary': 'var(--primary)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className="sticky top-0 z-10 border-b border-[var(--local-border)] bg-[var(--local-bg)]/95 backdrop-blur-xl">
      <div className="max-w-[1200px] mx-auto px-8">
        {data.announcement && <div className="border-b border-[var(--local-border)] py-2 text-center text-[0.72rem] font-mono uppercase tracking-[0.16em] text-[var(--local-text)]/70" data-jp-field="announcement">{data.announcement}</div>}
        <div className="flex h-20 items-center justify-between gap-6">
          <a href="/" className="flex items-baseline gap-2">
            <span className="font-display text-2xl tracking-tight text-[var(--local-text)]" data-jp-field="logoText">{data.logoText}</span>
            {data.logoHighlight && <span className="font-mono text-[0.72rem] uppercase tracking-[0.24em] text-[var(--local-primary)]" data-jp-field="logoHighlight">{data.logoHighlight}</span>}
          </a>
          <div className="hidden items-center gap-4 lg:flex">
            <NavigationMenu>
              <NavigationMenuList className="gap-1">
                {navItems.map((item, idx) => (
                  <NavigationMenuItem key={item.id || item.href + '-' + idx} data-jp-item-id={item.id || 'menu-' + idx} data-jp-item-field="menu">
                    <NavigationMenuLink href={item.href} className="rounded-[var(--local-radius-md)] px-4 py-2 text-sm font-medium text-[var(--local-text)] transition hover:bg-[var(--local-surface)]">{item.label}</NavigationMenuLink>
                  </NavigationMenuItem>
                ))}
              </NavigationMenuList>
            </NavigationMenu>
            <Button type="button" variant="outline" onClick={toggleTheme} className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]">{theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}</Button>
          </div>
          <div className="flex items-center gap-3 lg:hidden">
            <Button type="button" variant="outline" onClick={toggleTheme} className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]">{theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}</Button>
            <Sheet>
              <SheetTrigger asChild><Button variant="outline" className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"><Menu className="h-4 w-4" /></Button></SheetTrigger>
              <SheetContent className="flex flex-col gap-0 bg-card text-foreground">
                <SheetHeader className="border-b border-border px-6 py-5"><SheetTitle className="font-display text-lg text-foreground">{data.logoText || 'Menu'}</SheetTitle></SheetHeader>
                <nav className="flex flex-1 flex-col divide-y divide-border overflow-y-auto">
                  {navItems.map((item, idx) => (
                    <SheetClose asChild key={item.id || item.href + '-m-' + idx}><a href={item.href} className="flex items-center px-6 py-4 text-base font-medium text-foreground hover:bg-muted">{item.label}</a></SheetClose>
                  ))}
                </nav>
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </div>
    </header>
  );
};
EOF
cat > src/components/header/index.ts << 'EOF'
export { Header } from './View';
export { HeaderSchema } from './schema';
export type { HeaderData, HeaderSettings } from './types';
EOF

echo "-- Writing capsule: footer..."
cat > src/components/footer/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';
const FooterMenuItemSchema = BaseArrayItem.extend({ label: z.string().describe('ui:text'), href: z.string().describe('ui:text') });
const FooterSocialItemSchema = BaseArrayItem.extend({ label: z.string().describe('ui:text'), href: z.string().describe('ui:text'), icon: z.string().describe('ui:icon-picker') });
export const FooterSchema = BaseSectionData.extend({
  brandText: z.string().describe('ui:text'),
  brandHighlight: z.string().optional().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  copyright: z.string().describe('ui:text'),
  menu: z.array(FooterMenuItemSchema).optional().describe('ui:list'),
  social: z.array(FooterSocialItemSchema).optional().describe('ui:list'),
});
EOF
cat > src/components/footer/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { FooterSchema } from './schema';
export type FooterData = z.infer<typeof FooterSchema>;
export type FooterSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/footer/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Separator } from '@/components/ui/separator';
import { Icon } from '@/lib/IconResolver';
import type { FooterData, FooterSettings } from './types';
export const Footer: React.FC<{ data: FooterData; settings: FooterSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];
  const socialItems = Array.isArray(data.social) ? data.social : [];
  return (
    <footer style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-border': 'var(--border)', '--local-primary': 'var(--primary)' } as React.CSSProperties} className="relative z-0 border-t border-[var(--local-border)] bg-[var(--local-bg)] py-20">
      <div className="max-w-[1200px] mx-auto px-8">
        <div className="grid gap-12 md:grid-cols-3">
          <div>
            <h3 className="font-display text-2xl text-[var(--local-text)]" data-jp-field="brandText">{data.brandText}</h3>
            {data.brandHighlight && <p className="mt-1 font-mono text-[0.7rem] uppercase tracking-[0.2em] text-[var(--local-primary)]" data-jp-field="brandHighlight">{data.brandHighlight}</p>}
            {data.description && <p className="mt-4 max-w-sm text-sm text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
          </div>
          <div>
            <p className="mb-4 font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--local-text-muted)]">Navigate</p>
            <nav className="flex flex-col gap-3">
              {navItems.map((item, idx) => (
                <a key={item.id || 'menu-' + idx} href={item.href} data-jp-item-id={item.id || 'menu-' + idx} data-jp-item-field="menu" className="text-sm text-[var(--local-text)] hover:text-[var(--local-primary)]">{item.label}</a>
              ))}
            </nav>
          </div>
          <div>
            <p className="mb-4 font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--local-text-muted)]">Social</p>
            <div className="flex flex-col gap-3">
              {socialItems.map((item, idx) => (
                <a key={item.id || 'social-' + idx} href={item.href} target="_blank" rel="noreferrer" data-jp-item-id={item.id || 'social-' + idx} data-jp-item-field="social" className="inline-flex items-center gap-2 text-sm text-[var(--local-text)] hover:text-[var(--local-primary)]"><Icon name={item.icon} size={16} /><span>{item.label}</span></a>
              ))}
            </div>
          </div>
        </div>
        <Separator className="my-10 bg-[var(--local-border)]" />
        <p className="font-mono text-xs text-[var(--local-text-muted)]" data-jp-field="copyright">{data.copyright}</p>
      </div>
    </footer>
  );
};
EOF
cat > src/components/footer/index.ts << 'EOF'
export { Footer } from './View';
export { FooterSchema } from './schema';
export type { FooterData, FooterSettings } from './types';
EOF

# Shared padding helper note: each capsule inlines PADDING maps per skill.

write_capsule_types() {
  local dir="$1" schema="$2" dataType="$3" settingsType="$4"
  cat > "src/components/${dir}/types.ts" << EOF
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ${schema} } from './schema';
export type ${dataType} = z.infer<typeof ${schema}>;
export type ${settingsType} = z.infer<typeof BaseSectionSettingsSchema>;
EOF
  cat > "src/components/${dir}/index.ts" << EOF
export { ${dataType%Data} } from './View';
export { ${schema} } from './schema';
export type { ${dataType}, ${settingsType} } from './types';
EOF
}

# --- home-hero ---
echo "-- Writing capsule: home-hero..."
cat > src/components/home-hero/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';
export const HomeHeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  titleHighlight: z.string().optional().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  primaryCta: CtaSchema.optional(),
  secondaryCta: CtaSchema.optional(),
});
EOF
cat > src/components/home-hero/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { HomeHeroSchema } from './schema';
export type HomeHeroData = z.infer<typeof HomeHeroSchema>;
export type HomeHeroSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/home-hero/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { HomeHeroData, HomeHeroSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const HomeHero: React.FC<{ data: HomeHeroData; settings: HomeHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-border': 'var(--border)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="max-w-3xl jp-animate-in">
          {data.label && <div className="mb-6 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
          <h1 className="font-display font-black text-[clamp(3rem,6vw,5.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}{data.titleHighlight ? <>{' '}<em className="not-italic text-[var(--local-primary)]" data-jp-field="titleHighlight">{data.titleHighlight}</em></> : null}</h1>
          <p className="mt-8 max-w-2xl text-lg text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>
          <div className="mt-10 flex flex-wrap gap-4">
            {data.primaryCta && <Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5"><a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a></Button>}
            {data.secondaryCta && <Button asChild variant="outline" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5"><a href={data.secondaryCta.href} data-jp-field="secondaryCta">{data.secondaryCta.label}</a></Button>}
          </div>
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/home-hero/index.ts << 'EOF'
export { HomeHero } from './View';
export { HomeHeroSchema } from './schema';
export type { HomeHeroData, HomeHeroSettings } from './types';
EOF

# --- featured-projects ---
echo "-- Writing capsule: featured-projects..."
cat > src/components/featured-projects/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';
export const FeaturedProjectsSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  limit: z.number().default(4).describe('ui:number'),
  items: z.record(z.string(), ProjectSchema).describe('ui:collection-ref'),
});
EOF
cat > src/components/featured-projects/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { FeaturedProjectsSchema } from './schema';
export type FeaturedProjectsData = z.infer<typeof FeaturedProjectsSchema>;
export type FeaturedProjectsSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/featured-projects/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
import React, { useMemo } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { Project } from '@/collections/projects';
import type { FeaturedProjectsData, FeaturedProjectsSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const FeaturedProjects: React.FC<{ data: FeaturedProjectsData; settings: FeaturedProjectsSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const projects = useMemo(() => {
    const all = Object.values(data.items ?? {}) as Project[];
    const featured = all.filter((p) => p.featured).sort((a, b) => b.year - a.year);
    const source = featured.length > 0 ? featured : all.sort((a, b) => b.year - a.year);
    return source.slice(0, Math.max(1, data.limit || 4));
  }, [data.items, data.limit]);
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        {data.description && <p className="mt-4 max-w-2xl text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
        <div className="mt-12 grid gap-4 md:grid-cols-4 md:auto-rows-[220px]">
          {projects.map((project, idx) => {
            const span = idx === 0 ? 'md:col-span-2 md:row-span-2' : idx === 1 ? 'md:col-span-2' : 'md:col-span-1';
            return (
              <a key={project.id || 'legacy-' + idx} href={'/work/' + project.id} data-jp-item-id={project.id || 'legacy-' + idx} data-jp-item-field="items" className={span + ' block'}>
                <Card className="h-full rounded-[var(--local-radius-lg)] border-[var(--local-border)] bg-[var(--local-surface)] transition hover:border-[var(--local-primary)]">
                  <CardContent className="flex h-full flex-col justify-between p-6">
                    <div>
                      <p className="font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--local-primary)]">{project.year}</p>
                      <h3 className="mt-3 font-display font-bold text-[1.2rem] text-[var(--local-text)]">{project.title}</h3>
                      <p className="mt-3 text-sm text-[var(--local-text-muted)]">{project.subtitle}</p>
                    </div>
                    <p className="mt-6 font-mono text-xs text-[var(--local-text-muted)]">{project.role}</p>
                  </CardContent>
                </Card>
              </a>
            );
          })}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/featured-projects/index.ts << 'EOF'
export { FeaturedProjects } from './View';
export { FeaturedProjectsSchema } from './schema';
export type { FeaturedProjectsData, FeaturedProjectsSettings } from './types';
EOF

# --- recent-posts ---
echo "-- Writing capsule: recent-posts..."
cat > src/components/recent-posts/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';
export const RecentPostsSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  limit: z.number().default(3).describe('ui:number'),
  items: z.record(z.string(), PostSchema).describe('ui:collection-ref'),
});
EOF
cat > src/components/recent-posts/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { RecentPostsSchema } from './schema';
export type RecentPostsData = z.infer<typeof RecentPostsSchema>;
export type RecentPostsSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/recent-posts/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React, { useMemo } from 'react';
import type { Post } from '@/collections/posts';
import type { RecentPostsData, RecentPostsSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const RecentPosts: React.FC<{ data: RecentPostsData; settings: RecentPostsSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const posts = useMemo(() => (Object.values(data.items ?? {}) as Post[]).sort((a, b) => b.date.localeCompare(a.date)).slice(0, Math.max(1, data.limit || 3)), [data.items, data.limit]);
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        <div className="mt-10 flex gap-6 overflow-x-auto pb-4">
          {posts.map((post, idx) => (
            <a key={post.id || 'legacy-' + idx} href={'/blog/' + post.id} data-jp-item-id={post.id || 'legacy-' + idx} data-jp-item-field="items" className="min-w-[280px] max-w-sm flex-1 rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6 hover:border-[var(--local-primary)]">
              <div className="flex gap-3 font-mono text-[0.7rem] uppercase tracking-[0.14em] text-[var(--local-text-muted)]"><span>{post.date}</span><span className="text-[var(--local-primary)]">{post.readingTime}</span></div>
              <h3 className="mt-4 font-display font-bold text-[1.2rem] text-[var(--local-text)]">{post.title}</h3>
              <p className="mt-3 text-sm text-[var(--local-text-muted)]">{post.dek}</p>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/recent-posts/index.ts << 'EOF'
export { RecentPosts } from './View';
export { RecentPostsSchema } from './schema';
export type { RecentPostsData, RecentPostsSettings } from './types';
EOF

# --- bio-band ---
echo "-- Writing capsule: bio-band..."
cat > src/components/bio-band/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema, ImageSelectionSchema } from '@olonjs/core';
export const BioBandSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea'),
  image: ImageSelectionSchema.optional(),
  cta: CtaSchema.optional(),
});
EOF
cat > src/components/bio-band/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { BioBandSchema } from './schema';
export type BioBandData = z.infer<typeof BioBandSchema>;
export type BioBandSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/bio-band/View.tsx << 'EOF'
// Layout: Hero=A (SPLIT 60/40), Features=E (TABBED)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { BioBandData, BioBandSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const BioBand: React.FC<{ data: BioBandData; settings: BioBandSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="grid items-center gap-12 md:grid-cols-[1.4fr_1fr]">
          <div>
            {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
            <p className="mt-6 whitespace-pre-line text-base leading-relaxed text-[var(--local-text-muted)]" data-jp-field="body">{data.body}</p>
            {data.cta && <div className="mt-8"><Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5"><a href={data.cta.href} data-jp-field="cta">{data.cta.label}</a></Button></div>}
          </div>
          {data.image?.url && <div className="overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]"><img src={data.image.url} alt={data.image.alt || ''} className="aspect-[4/5] w-full object-cover" data-jp-field="image" /></div>}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/bio-band/index.ts << 'EOF'
export { BioBand } from './View';
export { BioBandSchema } from './schema';
export type { BioBandData, BioBandSettings } from './types';
EOF

# --- cta-band ---
echo "-- Writing capsule: cta-band..."
cat > src/components/cta-band/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';
export const CtaBandSchema = BaseSectionData.extend({
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  primaryCta: CtaSchema,
});
EOF
cat > src/components/cta-band/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { CtaBandSchema } from './schema';
export type CtaBandData = z.infer<typeof CtaBandSchema>;
export type CtaBandSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/cta-band/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=D (ACCORDION)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { CtaBandData, CtaBandSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const CtaBand: React.FC<{ data: CtaBandData; settings: CtaBandSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass + ' text-center'}>
        <h2 className="font-display font-black text-[clamp(3rem,7vw,6.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        {data.description && <p className="mx-auto mt-6 max-w-xl text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
        <div className="mt-10"><Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5"><a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a></Button></div>
      </div>
    </section>
  );
};
EOF
cat > src/components/cta-band/index.ts << 'EOF'
export { CtaBand } from './View';
export { CtaBandSchema } from './schema';
export type { CtaBandData, CtaBandSettings } from './types';
EOF

# --- page-hero ---
echo "-- Writing capsule: page-hero..."
cat > src/components/page-hero/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
export const PageHeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
});
EOF
cat > src/components/page-hero/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PageHeroSchema } from './schema';
export type PageHeroData = z.infer<typeof PageHeroSchema>;
export type PageHeroSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/page-hero/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=C (TIMELINE)
import React from 'react';
import type { PageHeroData, PageHeroSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const PageHero: React.FC<{ data: PageHeroData; settings: PageHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass + ' max-w-3xl'}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h1 className="font-display font-black text-[clamp(2.5rem,5vw,4.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h1>
        {data.description && <p className="mt-6 text-lg text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
      </div>
    </section>
  );
};
EOF
cat > src/components/page-hero/index.ts << 'EOF'
export { PageHero } from './View';
export { PageHeroSchema } from './schema';
export type { PageHeroData, PageHeroSettings } from './types';
EOF

# --- about-story ---
echo "-- Writing capsule: about-story..."
cat > src/components/about-story/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, ImageSelectionSchema } from '@olonjs/core';
export const AboutStorySchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea'),
  image: ImageSelectionSchema.optional(),
});
EOF
cat > src/components/about-story/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { AboutStorySchema } from './schema';
export type AboutStoryData = z.infer<typeof AboutStorySchema>;
export type AboutStorySettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/about-story/View.tsx << 'EOF'
// Layout: Hero=D (EDITORIAL), Features=C (TIMELINE)
import React from 'react';
import type { AboutStoryData, AboutStorySettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const AboutStory: React.FC<{ data: AboutStoryData; settings: AboutStorySettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="grid gap-12 md:grid-cols-2 md:items-start">
          <div>
            {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
            <p className="mt-6 whitespace-pre-line text-base leading-relaxed text-[var(--local-text-muted)]" data-jp-field="body">{data.body}</p>
          </div>
          {data.image?.url && <div className="overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]"><img src={data.image.url} alt={data.image.alt || ''} className="aspect-square w-full object-cover" data-jp-field="image" /></div>}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/about-story/index.ts << 'EOF'
export { AboutStory } from './View';
export { AboutStorySchema } from './schema';
export type { AboutStoryData, AboutStorySettings } from './types';
EOF

# --- skills-stack ---
echo "-- Writing capsule: skills-stack..."
cat > src/components/skills-stack/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';
const SkillItemSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  category: z.string().optional().describe('ui:text'),
  icon: z.string().describe('ui:icon-picker'),
});
export const SkillsStackSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  items: z.array(SkillItemSchema).describe('ui:list'),
});
EOF
cat > src/components/skills-stack/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { SkillsStackSchema } from './schema';
export type SkillsStackData = z.infer<typeof SkillsStackSchema>;
export type SkillsStackSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/skills-stack/View.tsx << 'EOF'
// Layout: Hero=B (BENTO GRID), Features=A (BENTO)
import React from 'react';
import { Icon } from '@/lib/IconResolver';
import type { SkillsStackData, SkillsStackSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const SkillsStack: React.FC<{ data: SkillsStackData; settings: SkillsStackSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {data.items.map((item, idx) => (
            <div key={item.id || 'legacy-' + idx} data-jp-item-id={item.id || 'legacy-' + idx} data-jp-item-field="items" className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-5">
              <Icon name={item.icon} size={20} className="text-[var(--local-primary)]" />
              <h3 className="mt-4 font-display font-bold text-[1.05rem] text-[var(--local-text)]">{item.label}</h3>
              {item.category && <p className="mt-1 font-mono text-[0.7rem] uppercase tracking-[0.14em] text-[var(--local-text-muted)]">{item.category}</p>}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/skills-stack/index.ts << 'EOF'
export { SkillsStack } from './View';
export { SkillsStackSchema } from './schema';
export type { SkillsStackData, SkillsStackSettings } from './types';
EOF

# --- philosophy ---
echo "-- Writing capsule: philosophy..."
cat > src/components/philosophy/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';
const PhilosophyItemSchema = BaseArrayItem.extend({
  title: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea'),
});
export const PhilosophySchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  items: z.array(PhilosophyItemSchema).describe('ui:list'),
});
EOF
cat > src/components/philosophy/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PhilosophySchema } from './schema';
export type PhilosophyData = z.infer<typeof PhilosophySchema>;
export type PhilosophySettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/philosophy/View.tsx << 'EOF'
// Layout: Hero=E (MAGAZINE), Features=D (ACCORDION)
import React from 'react';
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/accordion';
import type { PhilosophyData, PhilosophySettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const Philosophy: React.FC<{ data: PhilosophyData; settings: PhilosophySettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass + ' max-w-3xl'}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        <Accordion type="single" collapsible className="mt-10 border-t border-[var(--local-border)]">
          {data.items.map((item, idx) => (
            <AccordionItem key={item.id || 'legacy-' + idx} value={item.id || 'item-' + idx} data-jp-item-id={item.id || 'legacy-' + idx} data-jp-item-field="items" className="border-[var(--local-border)]">
              <AccordionTrigger className="font-display text-left text-lg text-[var(--local-text)] hover:no-underline">{item.title}</AccordionTrigger>
              <AccordionContent className="text-[var(--local-text-muted)]">{item.body}</AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </section>
  );
};
EOF
cat > src/components/philosophy/index.ts << 'EOF'
export { Philosophy } from './View';
export { PhilosophySchema } from './schema';
export type { PhilosophyData, PhilosophySettings } from './types';
EOF

# --- projects-list ---
echo "-- Writing capsule: projects-list..."
cat > src/components/projects-list/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';
export const ProjectsListSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), ProjectSchema).describe('ui:collection-ref'),
});
EOF
cat > src/components/projects-list/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ProjectsListSchema } from './schema';
export type ProjectsListData = z.infer<typeof ProjectsListSchema>;
export type ProjectsListSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/projects-list/View.tsx << 'EOF'
// Layout: Hero=B (BENTO GRID), Features=A (BENTO)
import React, { useMemo } from 'react';
import type { Project } from '@/collections/projects';
import type { ProjectsListData, ProjectsListSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const ProjectsList: React.FC<{ data: ProjectsListData; settings: ProjectsListSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const projects = useMemo(() => (Object.values(data.items ?? {}) as Project[]).sort((a, b) => b.year - a.year), [data.items]);
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        {data.description && <p className="mt-4 max-w-2xl text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
        <div className="mt-12 grid gap-4 md:grid-cols-2">
          {projects.map((project, idx) => (
            <a key={project.id || 'legacy-' + idx} href={'/work/' + project.id} data-jp-item-id={project.id || 'legacy-' + idx} data-jp-item-field="items" className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-8 transition hover:border-[var(--local-primary)]">
              <p className="font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--local-primary)]">{project.year} · {project.role}</p>
              <h3 className="mt-3 font-display font-bold text-2xl text-[var(--local-text)]">{project.title}</h3>
              <p className="mt-3 text-sm text-[var(--local-text-muted)]">{project.subtitle}</p>
              <p className="mt-6 text-sm text-[var(--local-text-muted)] line-clamp-3">{project.result}</p>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/projects-list/index.ts << 'EOF'
export { ProjectsList } from './View';
export { ProjectsListSchema } from './schema';
export type { ProjectsListData, ProjectsListSettings } from './types';
EOF

# --- project-detail ---
echo "-- Writing capsule: project-detail..."
cat > src/components/project-detail/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';
export const ProjectDetailSchema = BaseSectionData.extend({
  item: ProjectSchema.describe('ui:collection-ref'),
  backLabel: z.string().default('Back to work').describe('ui:text'),
});
EOF
cat > src/components/project-detail/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ProjectDetailSchema } from './schema';
export type ProjectDetailData = z.infer<typeof ProjectDetailSchema>;
export type ProjectDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/project-detail/View.tsx << 'EOF'
// Layout: Hero=D (EDITORIAL), Features=C (TIMELINE)
import React from 'react';
import { Badge } from '@/components/ui/badge';
import type { ProjectDetailData, ProjectDetailSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const ProjectDetail: React.FC<{ data: ProjectDetailData; settings: ProjectDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const item = data.item;
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <a href="/work" className="font-mono text-xs uppercase tracking-[0.16em] text-[var(--local-primary)]" data-jp-field="backLabel">{data.backLabel}</a>
        <p className="mt-8 font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)]">{item.year} · {item.role}</p>
        <h1 className="mt-4 font-display font-black text-[clamp(2.5rem,5vw,4.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]">{item.title}</h1>
        <p className="mt-4 text-xl text-[var(--local-text-muted)]">{item.subtitle}</p>
        {item.image?.url && <div className="mt-10 overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]"><img src={item.image.url} alt={item.image.alt || ''} className="aspect-[21/9] w-full object-cover" /></div>}
        <div className="mt-12 grid gap-10 md:grid-cols-2">
          <div><h2 className="font-display text-xl text-[var(--local-text)]">Context</h2><p className="mt-3 text-[var(--local-text-muted)]">{item.context}</p></div>
          <div><h2 className="font-display text-xl text-[var(--local-text)]">Problem</h2><p className="mt-3 text-[var(--local-text-muted)]">{item.problem}</p></div>
          <div><h2 className="font-display text-xl text-[var(--local-text)]">Architecture</h2><p className="mt-3 text-[var(--local-text-muted)]">{item.architecture}</p></div>
          <div><h2 className="font-display text-xl text-[var(--local-text)]">Result</h2><p className="mt-3 text-[var(--local-text-muted)]">{item.result}</p></div>
        </div>
        <div className="mt-12">
          <h2 className="font-display text-xl text-[var(--local-text)]">Stack</h2>
          <div className="mt-4 flex flex-wrap gap-2">{(item.stack || []).map((s) => <Badge key={s} variant="outline" className="rounded-[var(--theme-radius-md)] border-[var(--local-border)] font-mono text-[0.7rem] uppercase tracking-[0.12em] text-[var(--local-text)]">{s}</Badge>)}</div>
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/project-detail/index.ts << 'EOF'
export { ProjectDetail } from './View';
export { ProjectDetailSchema } from './schema';
export type { ProjectDetailData, ProjectDetailSettings } from './types';
EOF

# --- posts-list ---
echo "-- Writing capsule: posts-list..."
cat > src/components/posts-list/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';
export const PostsListSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), PostSchema).describe('ui:collection-ref'),
});
EOF
cat > src/components/posts-list/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PostsListSchema } from './schema';
export type PostsListData = z.infer<typeof PostsListSchema>;
export type PostsListSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/posts-list/View.tsx << 'EOF'
// Layout: Hero=E (MAGAZINE), Features=B (HORIZONTAL SCROLL)
import React, { useMemo } from 'react';
import type { Post } from '@/collections/posts';
import type { PostsListData, PostsListSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const PostsList: React.FC<{ data: PostsListData; settings: PostsListSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const posts = useMemo(() => (Object.values(data.items ?? {}) as Post[]).sort((a, b) => b.date.localeCompare(a.date)), [data.items]);
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        {data.description && <p className="mt-4 max-w-2xl text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
        <div className="mt-12 divide-y divide-[var(--local-border)] border-y border-[var(--local-border)]">
          {posts.map((post, idx) => (
            <a key={post.id || 'legacy-' + idx} href={'/blog/' + post.id} data-jp-item-id={post.id || 'legacy-' + idx} data-jp-item-field="items" className="grid gap-4 py-8 transition hover:opacity-80 md:grid-cols-[180px_1fr]">
              <div className="font-mono text-[0.7rem] uppercase tracking-[0.14em] text-[var(--local-text-muted)]"><div>{post.date}</div><div className="mt-1 text-[var(--local-primary)]">{post.readingTime}</div></div>
              <div><h3 className="font-display font-bold text-2xl text-[var(--local-text)]">{post.title}</h3><p className="mt-3 text-[var(--local-text-muted)]">{post.dek}</p></div>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/posts-list/index.ts << 'EOF'
export { PostsList } from './View';
export { PostsListSchema } from './schema';
export type { PostsListData, PostsListSettings } from './types';
EOF

# --- post-detail ---
echo "-- Writing capsule: post-detail..."
cat > src/components/post-detail/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';
export const PostDetailSchema = BaseSectionData.extend({
  item: PostSchema.describe('ui:collection-ref'),
  backLabel: z.string().default('Back to blog').describe('ui:text'),
});
EOF
cat > src/components/post-detail/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PostDetailSchema } from './schema';
export type PostDetailData = z.infer<typeof PostDetailSchema>;
export type PostDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/post-detail/View.tsx << 'EOF'
// Layout: Hero=D (EDITORIAL), Features=E (TABBED)
import React from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeSanitize from 'rehype-sanitize';
import { Badge } from '@/components/ui/badge';
import type { PostDetailData, PostDetailSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const PostDetail: React.FC<{ data: PostDetailData; settings: PostDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const item = data.item;
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass + ' max-w-3xl'}>
        <a href="/blog" className="font-mono text-xs uppercase tracking-[0.16em] text-[var(--local-primary)]" data-jp-field="backLabel">{data.backLabel}</a>
        <div className="mt-8 flex flex-wrap gap-3 font-mono text-[0.7rem] uppercase tracking-[0.14em] text-[var(--local-text-muted)]"><span>{item.date}</span><span className="text-[var(--local-primary)]">{item.readingTime}</span></div>
        <h1 className="mt-4 font-display font-black text-[clamp(2.5rem,5vw,4.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]">{item.title}</h1>
        <p className="mt-6 text-xl text-[var(--local-text-muted)]">{item.dek}</p>
        <div className="mt-4 flex flex-wrap gap-2">{(item.tags || []).map((tag) => <Badge key={tag} variant="outline" className="rounded-[var(--theme-radius-md)] border-[var(--local-border)] font-mono text-[0.65rem] uppercase tracking-[0.12em]">{tag}</Badge>)}</div>
        {item.image?.url && <div className="mt-10 overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]"><img src={item.image.url} alt={item.image.alt || ''} className="aspect-[16/9] w-full object-cover" /></div>}
        <article className="prose prose-invert mt-12 max-w-none text-[var(--local-text)] [&_h2]:font-display [&_h2]:text-2xl [&_h2]:mt-10 [&_p]:text-[var(--local-text-muted)] [&_p]:leading-relaxed [&_code]:font-mono [&_code]:text-[var(--local-primary)]">
          <ReactMarkdown remarkPlugins={[remarkGfm]} rehypePlugins={[rehypeSanitize]}>{item.body}</ReactMarkdown>
        </article>
      </div>
    </section>
  );
};
EOF
cat > src/components/post-detail/index.ts << 'EOF'
export { PostDetail } from './View';
export { PostDetailSchema } from './schema';
export type { PostDetailData, PostDetailSettings } from './types';
EOF

# --- contact-form ---
echo "-- Writing capsule: contact-form..."
cat > src/components/contact-form/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData, WithFormRecipient } from '@olonjs/core';
const SocialLinkSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  icon: z.string().describe('ui:icon-picker'),
});
export const ContactFormSchema = BaseSectionData.merge(WithFormRecipient).extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  submitLabel: z.string().default('Send message').describe('ui:text'),
  successMessage: z.string().default('Message sent. I will reply soon.').describe('ui:text'),
  social: z.array(SocialLinkSchema).optional().describe('ui:list'),
});
export const ContactFormSubmissionSchema = z.object({
  name: z.string().min(1).describe('Full name'),
  email: z.string().email().describe('Reply email'),
  message: z.string().min(1).describe('Message body'),
});
EOF
cat > src/components/contact-form/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ContactFormSchema } from './schema';
export type ContactFormData = z.infer<typeof ContactFormSchema>;
export type ContactFormSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/contact-form/View.tsx << 'EOF'
'use client';

// Layout: Hero=F (MINIMAL HERO), Features=D (ACCORDION)
import React from 'react';
import { useFormState } from '@olonjs/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Icon } from '@/lib/IconResolver';
import type { ContactFormData, ContactFormSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const ContactForm: React.FC<{ data: ContactFormData; settings: ContactFormSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const formId = data.anchorId?.trim() || 'contact-form';
  const { status, message } = useFormState(formId);
  const socialItems = Array.isArray(data.social) ? data.social : [];
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-md': 'var(--theme-radius-md)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="grid gap-12 md:grid-cols-2">
          <div>
            {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
            {data.description && <p className="mt-4 text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
            <div className="mt-8 flex flex-col gap-3">
              {socialItems.map((item, idx) => (
                <a key={item.id || 'social-' + idx} href={item.href} target="_blank" rel="noreferrer" data-jp-item-id={item.id || 'social-' + idx} data-jp-item-field="social" className="inline-flex items-center gap-2 text-sm text-[var(--local-text)] hover:text-[var(--local-primary)]"><Icon name={item.icon} size={16} /><span>{item.label}</span></a>
              ))}
            </div>
          </div>
          <form id={formId} data-olon-recipient={data.recipientEmail ?? ''} className="space-y-4 rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6">
            <div><Label htmlFor={formId + '-name'} className="text-[var(--local-text-muted)]">Name</Label><Input id={formId + '-name'} name="name" required className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <div><Label htmlFor={formId + '-email'} className="text-[var(--local-text-muted)]">Email</Label><Input id={formId + '-email'} name="email" type="email" required className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <div><Label htmlFor={formId + '-message'} className="text-[var(--local-text-muted)]">Message</Label><Textarea id={formId + '-message'} name="message" required rows={6} className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <Button type="submit" variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5" data-jp-field="submitLabel">{data.submitLabel}</Button>
            {status === 'success' && <p className="text-sm text-[var(--local-primary)]" data-jp-field="successMessage">{data.successMessage}</p>}
            {status === 'error' && <p className="text-sm text-destructive">{message || 'Something went wrong.'}</p>}
          </form>
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/contact-form/index.ts << 'EOF'
export { ContactForm } from './View';
export { ContactFormSchema, ContactFormSubmissionSchema } from './schema';
export type { ContactFormData, ContactFormSettings } from './types';
EOF

# =============================================================================
# WIRING — types / registry / schemas / addSectionConfig
# =============================================================================
echo "-- Writing src/types.ts..."
cat > src/types.ts << 'EOF'
import type { HeaderData, HeaderSettings } from '@/components/header';
import type { FooterData, FooterSettings } from '@/components/footer';
import type { HomeHeroData, HomeHeroSettings } from '@/components/home-hero';
import type { FeaturedProjectsData, FeaturedProjectsSettings } from '@/components/featured-projects';
import type { RecentPostsData, RecentPostsSettings } from '@/components/recent-posts';
import type { BioBandData, BioBandSettings } from '@/components/bio-band';
import type { CtaBandData, CtaBandSettings } from '@/components/cta-band';
import type { PageHeroData, PageHeroSettings } from '@/components/page-hero';
import type { AboutStoryData, AboutStorySettings } from '@/components/about-story';
import type { SkillsStackData, SkillsStackSettings } from '@/components/skills-stack';
import type { PhilosophyData, PhilosophySettings } from '@/components/philosophy';
import type { ProjectsListData, ProjectsListSettings } from '@/components/projects-list';
import type { ProjectDetailData, ProjectDetailSettings } from '@/components/project-detail';
import type { PostsListData, PostsListSettings } from '@/components/posts-list';
import type { PostDetailData, PostDetailSettings } from '@/components/post-detail';
import type { ContactFormData, ContactFormSettings } from '@/components/contact-form';
import type { Project } from '@/collections/projects';
import type { Post } from '@/collections/posts';

export type SectionComponentPropsMap = {
  header: { data: HeaderData; settings: HeaderSettings };
  footer: { data: FooterData; settings: FooterSettings };
  'home-hero': { data: HomeHeroData; settings: HomeHeroSettings };
  'featured-projects': { data: FeaturedProjectsData; settings: FeaturedProjectsSettings };
  'recent-posts': { data: RecentPostsData; settings: RecentPostsSettings };
  'bio-band': { data: BioBandData; settings: BioBandSettings };
  'cta-band': { data: CtaBandData; settings: CtaBandSettings };
  'page-hero': { data: PageHeroData; settings: PageHeroSettings };
  'about-story': { data: AboutStoryData; settings: AboutStorySettings };
  'skills-stack': { data: SkillsStackData; settings: SkillsStackSettings };
  philosophy: { data: PhilosophyData; settings: PhilosophySettings };
  'projects-list': { data: ProjectsListData; settings: ProjectsListSettings };
  'project-detail': { data: ProjectDetailData; settings: ProjectDetailSettings };
  'posts-list': { data: PostsListData; settings: PostsListSettings };
  'post-detail': { data: PostDetailData; settings: PostDetailSettings };
  'contact-form': { data: ContactFormData; settings: ContactFormSettings };
};

declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    header: HeaderData;
    footer: FooterData;
    'home-hero': HomeHeroData;
    'featured-projects': FeaturedProjectsData;
    'recent-posts': RecentPostsData;
    'bio-band': BioBandData;
    'cta-band': CtaBandData;
    'page-hero': PageHeroData;
    'about-story': AboutStoryData;
    'skills-stack': SkillsStackData;
    philosophy: PhilosophyData;
    'projects-list': ProjectsListData;
    'project-detail': ProjectDetailData;
    'posts-list': PostsListData;
    'post-detail': PostDetailData;
    'contact-form': ContactFormData;
  }
  export interface SectionSettingsRegistry {
    header: HeaderSettings;
    footer: FooterSettings;
    'home-hero': HomeHeroSettings;
    'featured-projects': FeaturedProjectsSettings;
    'recent-posts': RecentPostsSettings;
    'bio-band': BioBandSettings;
    'cta-band': CtaBandSettings;
    'page-hero': PageHeroSettings;
    'about-story': AboutStorySettings;
    'skills-stack': SkillsStackSettings;
    philosophy: PhilosophySettings;
    'projects-list': ProjectsListSettings;
    'project-detail': ProjectDetailSettings;
    'posts-list': PostsListSettings;
    'post-detail': PostDetailSettings;
    'contact-form': ContactFormSettings;
  }
  export interface CollectionItemRegistry {
    projects: Project;
    posts: Post;
  }
}

export * from '@olonjs/core';
EOF

echo "-- Writing ComponentRegistry / schemas / addSectionConfig..."
cat > src/lib/ComponentRegistry.tsx << 'EOF'
import type { SectionType } from '@/types';
import type { SectionComponentPropsMap } from '@/types';
import { Header } from '@/components/header';
import { Footer } from '@/components/footer';
import { HomeHero } from '@/components/home-hero';
import { FeaturedProjects } from '@/components/featured-projects';
import { RecentPosts } from '@/components/recent-posts';
import { BioBand } from '@/components/bio-band';
import { CtaBand } from '@/components/cta-band';
import { PageHero } from '@/components/page-hero';
import { AboutStory } from '@/components/about-story';
import { SkillsStack } from '@/components/skills-stack';
import { Philosophy } from '@/components/philosophy';
import { ProjectsList } from '@/components/projects-list';
import { ProjectDetail } from '@/components/project-detail';
import { PostsList } from '@/components/posts-list';
import { PostDetail } from '@/components/post-detail';
import { ContactForm } from '@/components/contact-form';

export const ComponentRegistry: {
  [K in SectionType]: React.FC<SectionComponentPropsMap[K]>;
} = {
  header: Header,
  footer: Footer,
  'home-hero': HomeHero,
  'featured-projects': FeaturedProjects,
  'recent-posts': RecentPosts,
  'bio-band': BioBand,
  'cta-band': CtaBand,
  'page-hero': PageHero,
  'about-story': AboutStory,
  'skills-stack': SkillsStack,
  philosophy: Philosophy,
  'projects-list': ProjectsList,
  'project-detail': ProjectDetail,
  'posts-list': PostsList,
  'post-detail': PostDetail,
  'contact-form': ContactForm,
};
EOF

cat > src/lib/schemas.ts << 'EOF'
import { HeaderSchema } from '@/components/header';
import { FooterSchema } from '@/components/footer';
import { HomeHeroSchema } from '@/components/home-hero';
import { FeaturedProjectsSchema } from '@/components/featured-projects';
import { RecentPostsSchema } from '@/components/recent-posts';
import { BioBandSchema } from '@/components/bio-band';
import { CtaBandSchema } from '@/components/cta-band';
import { PageHeroSchema } from '@/components/page-hero';
import { AboutStorySchema } from '@/components/about-story';
import { SkillsStackSchema } from '@/components/skills-stack';
import { PhilosophySchema } from '@/components/philosophy';
import { ProjectsListSchema } from '@/components/projects-list';
import { ProjectDetailSchema } from '@/components/project-detail';
import { PostsListSchema } from '@/components/posts-list';
import { PostDetailSchema } from '@/components/post-detail';
import { ContactFormSchema, ContactFormSubmissionSchema } from '@/components/contact-form';

export const SECTION_SCHEMAS = {
  header: HeaderSchema,
  footer: FooterSchema,
  'home-hero': HomeHeroSchema,
  'featured-projects': FeaturedProjectsSchema,
  'recent-posts': RecentPostsSchema,
  'bio-band': BioBandSchema,
  'cta-band': CtaBandSchema,
  'page-hero': PageHeroSchema,
  'about-story': AboutStorySchema,
  'skills-stack': SkillsStackSchema,
  philosophy: PhilosophySchema,
  'projects-list': ProjectsListSchema,
  'project-detail': ProjectDetailSchema,
  'posts-list': PostsListSchema,
  'post-detail': PostDetailSchema,
  'contact-form': ContactFormSchema,
} as const;

export const SECTION_SUBMISSION_SCHEMAS = {
  'contact-form': ContactFormSubmissionSchema,
} as const;

export type SectionType = keyof typeof SECTION_SCHEMAS;

export {
  BaseSectionData,
  BaseArrayItem,
  BaseCollectionItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema,
} from '@olonjs/core';
EOF

cat > src/lib/addSectionConfig.ts << 'EOF'
import type { AddSectionConfig } from '@olonjs/core';

const addableSectionTypes = [
  'home-hero', 'featured-projects', 'recent-posts', 'bio-band', 'cta-band',
  'page-hero', 'about-story', 'skills-stack', 'philosophy', 'projects-list',
  'project-detail', 'posts-list', 'post-detail', 'contact-form',
] as const;

const sectionTypeLabels: Record<string, string> = {
  'home-hero': 'Home Hero',
  'featured-projects': 'Featured Projects',
  'recent-posts': 'Recent Posts',
  'bio-band': 'Bio Band',
  'cta-band': 'CTA Band',
  'page-hero': 'Page Hero',
  'about-story': 'About Story',
  'skills-stack': 'Skills Stack',
  philosophy: 'Philosophy',
  'projects-list': 'Projects List',
  'project-detail': 'Project Detail',
  'posts-list': 'Posts List',
  'post-detail': 'Post Detail',
  'contact-form': 'Contact Form',
};

function getDefaultSectionData(type: string): Record<string, unknown> {
  switch (type) {
    case 'home-hero': return { title: 'Headline', description: 'Positioning line.', primaryCta: { id: 'cta-1', label: 'Contact', href: '/contact', variant: 'primary' } };
    case 'featured-projects': return { title: 'Selected work', limit: 4, items: { $ref: '../collections/projects/projects.json' } };
    case 'recent-posts': return { title: 'Writing', limit: 3, items: { $ref: '../collections/posts/posts.json' } };
    case 'bio-band': return { title: 'About', body: 'Short bio.' };
    case 'cta-band': return { title: 'Get in touch', primaryCta: { id: 'cta-1', label: 'Contact', href: '/contact', variant: 'primary' } };
    case 'page-hero': return { title: 'Page title' };
    case 'about-story': return { title: 'Story', body: 'Career path.' };
    case 'skills-stack': return { title: 'Stack', items: [] };
    case 'philosophy': return { title: 'Principles', items: [] };
    case 'projects-list': return { title: 'Work', items: { $ref: '../collections/projects/projects.json' } };
    case 'project-detail': return { item: { $ref: 'collection:current' }, backLabel: 'Back to work' };
    case 'posts-list': return { title: 'Blog', items: { $ref: '../collections/posts/posts.json' } };
    case 'post-detail': return { item: { $ref: 'collection:current' }, backLabel: 'Back to blog' };
    case 'contact-form': return { title: 'Contact', submitLabel: 'Send message', successMessage: 'Message sent.', social: [] };
    default: return {};
  }
}

export const addSectionConfig: AddSectionConfig = {
  addableSectionTypes: [...addableSectionTypes],
  sectionTypeLabels,
  getDefaultSectionData,
};
EOF

# =============================================================================
# DATA — theme / site / menu / collections / pages
# =============================================================================
echo "-- Writing theme.json / site.json / menu.json..."
cat > src/data/config/theme.json << 'EOF'
{
  "name": "Andrew Linh",
  "tokens": {
    "colors": {
      "background": "#0a0a0a",
      "foreground": "#e8e8e6",
      "card": "#111111",
      "card-foreground": "#e8e8e6",
      "elevated": "#161616",
      "overlay": "#1c1c1c",
      "primary": "#3ddc84",
      "primary-foreground": "#06140c",
      "primary-light": "#6ee7a8",
      "primary-dark": "#22a35c",
      "accent": "#141414",
      "accent-foreground": "#e8e8e6",
      "secondary": "#151515",
      "secondary-foreground": "#e8e8e6",
      "muted": "#151515",
      "muted-foreground": "#8a8a86",
      "border": "#242424",
      "border-strong": "#333333",
      "input": "#242424",
      "ring": "#3ddc84",
      "destructive": "#b33a3a",
      "destructive-foreground": "#f5e9e9",
      "success": "#1f8a55",
      "success-foreground": "#e8e8e6",
      "warning": "#8a6b12",
      "warning-foreground": "#e8e8e6",
      "info": "#2a6f9a",
      "info-foreground": "#e8e8e6"
    },
    "typography": {
      "fontFamily": {
        "primary": "'Instrument Sans', system-ui, sans-serif",
        "mono": "'JetBrains Mono', monospace",
        "display": "'Instrument Serif', system-ui, serif"
      },
      "wordmark": {
        "fontFamily": "'Instrument Serif', system-ui, serif",
        "weight": "700"
      }
    },
    "borderRadius": { "sm": "2px", "md": "4px", "lg": "6px", "xl": "10px", "full": "9999px" },
    "spacing": {
      "container-max": "1200px",
      "section-y": "96px",
      "header-h": "80px",
      "sidebar-w": "240px"
    },
    "zIndex": {
      "base": "0", "elevated": "10", "dropdown": "100",
      "sticky": "200", "overlay": "300", "modal": "400", "toast": "500"
    },
    "modes": {
      "light": {
        "colors": {
          "background": "#f7f7f5",
          "foreground": "#121212",
          "card": "#ffffff",
          "card-foreground": "#121212",
          "elevated": "#efefec",
          "overlay": "#e4e4e0",
          "primary": "#0f7a45",
          "primary-foreground": "#f4fff8",
          "primary-light": "#1aa05c",
          "primary-dark": "#0a5a32",
          "accent": "#eef6f1",
          "accent-foreground": "#121212",
          "secondary": "#ecece8",
          "secondary-foreground": "#121212",
          "muted": "#ecece8",
          "muted-foreground": "#5c5c58",
          "border": "#d6d6d0",
          "border-strong": "#b8b8b0",
          "input": "#d6d6d0",
          "ring": "#0f7a45",
          "destructive": "#a12d2d",
          "destructive-foreground": "#fff5f5",
          "success": "#0f7a45",
          "success-foreground": "#f4fff8",
          "warning": "#8a6b12",
          "warning-foreground": "#121212",
          "info": "#1d5f88",
          "info-foreground": "#f4f9fc"
        }
      }
    }
  }
}
EOF

cat > src/data/config/site.json << 'EOF'
{
  "identity": {
    "title": "Andrew Linh"
  },
  "header": {
    "id": "global-header",
    "type": "header",
    "data": {
      "logoText": "Andrew Linh",
      "logoHighlight": "AL",
      "menu": { "$ref": "../config/menu.json#/main" }
    },
    "settings": { "sticky": true }
  },
  "footer": {
    "id": "global-footer",
    "type": "footer",
    "data": {
      "brandText": "Andrew Linh",
      "brandHighlight": "systems · writing",
      "description": "Systems architect and technical writer. Backend architectures, structured data infrastructure, developer tools, and AI-native systems.",
      "copyright": "© 2026 Andrew Linh.",
      "menu": { "$ref": "../config/menu.json#/footer" },
      "social": [
        { "id": "gh", "label": "GitHub", "href": "https://github.com/andrewlinh", "icon": "github" },
        { "id": "li", "label": "LinkedIn", "href": "https://linkedin.com/in/andrewlinh", "icon": "linkedin" },
        { "id": "rss", "label": "RSS", "href": "/blog/rss.xml", "icon": "rss" }
      ]
    },
    "settings": { "showLogo": true }
  }
}
EOF

cat > src/data/config/menu.json << 'EOF'
{
  "main": [
    { "id": "nav-about", "label": "About", "href": "/about" },
    { "id": "nav-work", "label": "Work", "href": "/work" },
    { "id": "nav-blog", "label": "Blog", "href": "/blog" },
    { "id": "nav-contact", "label": "Contact", "href": "/contact", "isCta": true }
  ],
  "footer": [
    { "id": "ft-work", "label": "Work", "href": "/work" },
    { "id": "ft-blog", "label": "Blog", "href": "/blog" },
    { "id": "ft-contact", "label": "Contact", "href": "/contact" },
    { "id": "ft-rss", "label": "RSS", "href": "/blog/rss.xml" }
  ]
}
EOF

echo "-- Writing collection data (projects + posts)..."
# Reuse existing rich JSON if present; otherwise write full content
if [ ! -f src/data/collections/projects/projects.json ] || [ ! -s src/data/collections/projects/projects.json ]; then
cat > src/data/collections/projects/projects.json << 'EOF'
{
  "schemaforge-cms": {
    "id": "schemaforge-cms",
    "title": "SchemaForge CMS",
    "subtitle": "Schema-driven content publishing for multi-tenant sites",
    "year": 2025,
    "role": "Lead systems architect",
    "context": "A content platform serving 40+ tenants needed deterministic page assembly without CMS drift or silent field mismatches.",
    "problem": "Editors published broken pages weekly because free-form JSON and ad-hoc React sections diverged. Publish errors averaged 12% of releases, and rollback windows stretched past two hours.",
    "architecture": "Introduced Zod collection contracts, keyed collection documents, and section capsules that bind via $ref. Studio inspector surfaces were generated from the same schemas used at render time. CI validated every page and collection against registry schemas before merge.",
    "result": "Publish errors dropped 40%. Mean time to recover from a bad content release fell from 2.1 hours to 18 minutes. New tenant onboarding time moved from weeks to a two-day scaffold.",
    "stack": ["TypeScript", "Zod", "React", "Vite", "PostgreSQL"],
    "image": { "url": "https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=1600&q=80", "alt": "Dark IDE with structured code on a widescreen monitor" },
    "tags": ["cms", "schemas", "content-infra"],
    "featured": true
  },
  "typebridge-api": {
    "id": "typebridge-api",
    "title": "Typebridge API",
    "subtitle": "End-to-end type safety from Zod to OpenAPI to clients",
    "year": 2024,
    "role": "Principal engineer",
    "context": "A developer-tools company shipped three client SDKs from a hand-maintained OpenAPI document that routinely drifted from runtime validators.",
    "problem": "Contract mismatches caused 23 production incidents in six months. SDK releases lagged API changes by an average of nine days.",
    "architecture": "Made Zod schemas the single source of truth. Generated OpenAPI 3.1, TypeScript clients, and contract tests from the same definitions.",
    "result": "Contract-related incidents fell 78%. SDK lag dropped from nine days to same-day.",
    "stack": ["Zod", "OpenAPI", "Node.js", "GitHub Actions"],
    "image": { "url": "https://images.unsplash.com/photo-1518770660439-4636190af475?w=1600&q=80", "alt": "Circuit board traces representing API connectivity" },
    "tags": ["api", "type-safety", "dx"],
    "featured": true
  },
  "agentops-runner": {
    "id": "agentops-runner",
    "title": "AgentOps Runner",
    "subtitle": "Deterministic evaluation harness for AI agent workflows",
    "year": 2025,
    "role": "Architecture lead",
    "context": "An AI product team needed reproducible evals for multi-step agents before promoting prompts and tools to production.",
    "problem": "Ad-hoc notebook evals produced non-comparable scores. Regressions slipped into production twice a month.",
    "architecture": "Built a runner with frozen fixtures, tool stubs, deterministic seeding, and structured trace artifacts with typed scorecards.",
    "result": "Eval variance across identical runs dropped below 1%. Production agent regressions fell from ~8/month to 1/month.",
    "stack": ["Python", "TypeScript", "Redis", "OpenTelemetry", "Docker"],
    "image": { "url": "https://images.unsplash.com/photo-1620712943543-bcc4688e7485?w=1600&q=80", "alt": "Abstract neural network visualization on a dark display" },
    "tags": ["ai", "evals", "observability"],
    "featured": true
  },
  "lakehouse-ledger": {
    "id": "lakehouse-ledger",
    "title": "Lakehouse Ledger",
    "subtitle": "Structured audit-trail infrastructure for regulated data pipelines",
    "year": 2023,
    "role": "Systems architect",
    "context": "A fintech data platform needed immutable lineage across batch and streaming transforms.",
    "problem": "Compliance reviews could not reconstruct metric definition changes. Audit prep consumed three engineer-weeks per quarter.",
    "architecture": "Designed an append-only ledger of schema versions, transform fingerprints, and partition manifests wired into Spark and Flink jobs.",
    "result": "Quarterly audit prep dropped from three engineer-weeks to four engineer-days. Lineage lookup latency stayed under 200ms p95.",
    "stack": ["Apache Iceberg", "Spark", "Flink", "PostgreSQL", "gRPC"],
    "image": { "url": "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=1600&q=80", "alt": "Earth from orbit with illuminated city lights" },
    "tags": ["data-infra", "audit", "lakehouse"],
    "featured": true
  }
}
EOF
fi

if [ ! -f src/data/collections/posts/posts.json ] || [ ! -s src/data/collections/posts/posts.json ]; then
cat > src/data/collections/posts/posts.json << 'EOF'
{
  "schema-driven-content": {
    "id": "schema-driven-content",
    "title": "Schema-driven content is the missing layer",
    "dek": "Why treating page sections as typed contracts beats free-form CMS blobs for multi-tenant sites.",
    "date": "2026-03-12",
    "readingTime": "9 min",
    "tags": ["schemas", "cms", "content-infra"],
    "image": { "url": "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=1600&q=80", "alt": "Laptop showing structured documents" },
    "body": "## The quiet failure mode\n\nMost content platforms fail the same way: the editor UI drifts from the renderer, and nobody notices until a publish breaks production.\n\n## Contracts over conventions\n\nSchema-driven content means every section, collection item, and form submission has a Zod contract shared by Studio, CI, and runtime.\n\n## The payoff\n\nYou trade a little authoring friction for operational calm. Publish errors become schema errors you can fix before merge."
  },
  "e2e-type-safety": {
    "id": "e2e-type-safety",
    "title": "End-to-end type safety without the ceremony",
    "dek": "How to keep Zod, OpenAPI, and generated clients honest without drowning teams in codegen rituals.",
    "date": "2026-01-28",
    "readingTime": "8 min",
    "tags": ["type-safety", "api", "dx"],
    "image": { "url": "https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=1600&q=80", "alt": "Developer working at a desk with code on screen" },
    "body": "## The split brain problem\n\nTeams often maintain three truths: runtime validators, OpenAPI, and handwritten clients.\n\n## One source, many projections\n\nStart with Zod at the boundary. Generate OpenAPI. Generate clients. Contract-test responses against the same types.\n\n## DX that sticks\n\nDevelopers adopt type safety when it removes toil."
  },
  "ai-agent-tooling": {
    "id": "ai-agent-tooling",
    "title": "Building AI agent tooling that can be graded",
    "dek": "Deterministic fixtures, typed traces, and golden scorecards turn agent demos into operable systems.",
    "date": "2025-11-04",
    "readingTime": "11 min",
    "tags": ["ai", "agents", "evals"],
    "image": { "url": "https://images.unsplash.com/photo-1677442136019-21780ecad995?w=1600&q=80", "alt": "Abstract glowing network suggesting AI systems" },
    "body": "## Demos are not systems\n\nAn agent that works in a notebook is not ready for production.\n\n## Make evaluation first-class\n\nDefine scenarios as data. Persist every tool call as a typed event log.\n\n## Calm over clever\n\nThe goal is an agent you can reason about — graded, bisected, and rolled back like any other service."
  },
  "dx-of-structured-systems": {
    "id": "dx-of-structured-systems",
    "title": "Developer experience for structured systems",
    "dek": "Precision tooling should feel quiet: fast feedback, honest errors, and fewer places to look.",
    "date": "2025-09-18",
    "readingTime": "7 min",
    "tags": ["dx", "tooling", "architecture"],
    "image": { "url": "https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=1600&q=80", "alt": "Laptop with code editor beside a notebook" },
    "body": "## DX is an architecture outcome\n\nIn structured systems, DX is the system. If the feedback loop is slow, the architecture will be circumvented.\n\n## Terminal aesthetics, human patience\n\nGood tools feel like a well-tuned terminal: dense signal, low noise, predictable commands."
  }
}
EOF
fi

echo "-- Writing pages..."
cat > src/data/pages/home.json << 'EOF'
{
  "id": "home-page",
  "slug": "home",
  "meta": {
    "title": "Andrew Linh — Systems Architect & Technical Writer",
    "description": "Portfolio and editorial site of Andrew Linh. Backend architecture, structured data infrastructure, developer tools, and AI-native systems — written with precision."
  },
  "sections": [
    {
      "id": "home-hero-1",
      "type": "home-hero",
      "data": {
        "label": "Systems architect · technical writer",
        "title": "I design backends that stay honest,",
        "titleHighlight": "then write about why.",
        "description": "Architecture for structured data platforms, developer tools, and AI-native systems — with the calm of a well-tuned terminal.",
        "primaryCta": { "id": "cta-work", "label": "View work", "href": "/work", "variant": "primary" },
        "secondaryCta": { "id": "cta-blog", "label": "Read writing", "href": "/blog", "variant": "secondary" }
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "lg" }
    },
    {
      "id": "home-featured-1",
      "type": "featured-projects",
      "data": {
        "label": "Selected work",
        "title": "Case studies",
        "description": "Four engagements where schema contracts, type safety, and measurable outcomes mattered more than slide decks.",
        "limit": 4,
        "items": { "$ref": "../collections/projects/projects.json" }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "md" }
    },
    {
      "id": "home-posts-1",
      "type": "recent-posts",
      "data": {
        "label": "Writing",
        "title": "Latest notes",
        "limit": 3,
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "md" }
    },
    {
      "id": "home-bio-1",
      "type": "bio-band",
      "data": {
        "label": "Briefly",
        "title": "Precision over performance.",
        "body": "I spend most of my time on the seams: schemas that bind editors to runtimes, APIs that stay typed end-to-end, and agent tooling you can actually grade.\n\nThis site is the professional surface and the editorial notebook — same standards in both.",
        "image": {
          "url": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=1200&q=80",
          "alt": "Portrait of a man in a dark shirt looking calmly at the camera"
        },
        "cta": { "id": "bio-about", "label": "Full about", "href": "/about", "variant": "secondary" }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "md" }
    },
    {
      "id": "home-cta-1",
      "type": "cta-band",
      "data": {
        "title": "Need a calm systems partner?",
        "description": "Architecture reviews, schema design, and technical writing for teams shipping structured platforms.",
        "primaryCta": { "id": "cta-contact", "label": "Start a conversation", "href": "/contact", "variant": "primary" }
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/about.json << 'EOF'
{
  "id": "about-page",
  "slug": "about",
  "meta": {
    "title": "About Andrew Linh — Path, Stack, Principles",
    "description": "Professional path, technical stack, and design philosophy of Andrew Linh: systems architecture for structured data, developer tools, and AI-native platforms."
  },
  "sections": [
    {
      "id": "about-hero-1",
      "type": "page-hero",
      "data": {
        "label": "About",
        "title": "Built for precision, not spectacle.",
        "description": "A short path through the work: backends, contracts, and writing that keeps teams honest."
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "md" }
    },
    {
      "id": "about-story-1",
      "type": "about-story",
      "data": {
        "label": "Path",
        "title": "From data pipelines to content contracts.",
        "body": "I started in data infrastructure — lineage, ledgers, and systems that had to answer auditors without improvisation. That habit of append-only truth carried into developer tools and content platforms.\n\nToday I design backend architectures and write about the seams where schemas, APIs, and AI agents meet. The through-line is simple: make the structure visible, make failures loud, keep the surface calm.",
        "image": {
          "url": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=1200&q=80",
          "alt": "Portrait of Andrew Linh"
        }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "md" }
    },
    {
      "id": "about-skills-1",
      "type": "skills-stack",
      "data": {
        "label": "Stack",
        "title": "Tools I reach for",
        "items": [
          { "id": "sk-ts", "label": "TypeScript", "category": "Language", "icon": "code" },
          { "id": "sk-zod", "label": "Zod", "category": "Contracts", "icon": "braces" },
          { "id": "sk-node", "label": "Node.js", "category": "Runtime", "icon": "server" },
          { "id": "sk-pg", "label": "PostgreSQL", "category": "Data", "icon": "database" },
          { "id": "sk-redis", "label": "Redis", "category": "Infra", "icon": "workflow" },
          { "id": "sk-otel", "label": "OpenTelemetry", "category": "Observability", "icon": "cpu" },
          { "id": "sk-iceberg", "label": "Apache Iceberg", "category": "Lakehouse", "icon": "boxes" },
          { "id": "sk-cloud", "label": "Cloud / CI", "category": "Delivery", "icon": "cloud" }
        ]
      },
      "settings": { "paddingTop": "md", "paddingBottom": "md" }
    },
    {
      "id": "about-philosophy-1",
      "type": "philosophy",
      "data": {
        "label": "Principles",
        "title": "How I design",
        "items": [
          { "id": "ph-1", "title": "One source of truth", "body": "If a field exists in three places, it will disagree. Prefer generated projections of a single contract." },
          { "id": "ph-2", "title": "Fail before merge", "body": "Schema validation in CI is cheaper than incident response. Loud errors beat silent drift." },
          { "id": "ph-3", "title": "Grade what you ship", "body": "Agents, pipelines, and content systems need fixtures and scorecards — not demos that only work once." },
          { "id": "ph-4", "title": "Calm surfaces", "body": "Dense signal, low noise. The aesthetic of a good terminal is respect for attention." }
        ]
      },
      "settings": { "paddingTop": "md", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/work.json << 'EOF'
{
  "id": "work-page",
  "slug": "work",
  "meta": {
    "title": "Work — Case Studies by Andrew Linh",
    "description": "Selected systems architecture case studies: schema-driven CMS, end-to-end type safety, AI agent evals, and lakehouse audit infrastructure."
  },
  "sections": [
    {
      "id": "work-hero-1",
      "type": "page-hero",
      "data": {
        "label": "Work",
        "title": "Case studies with receipts.",
        "description": "Each project is its own entity — context, problem, architecture, result, and stack."
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "md" }
    },
    {
      "id": "work-list-1",
      "type": "projects-list",
      "data": {
        "title": "Selected engagements",
        "description": "Real systems work with measurable outcomes.",
        "items": { "$ref": "../collections/projects/projects.json" }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/blog.json << 'EOF'
{
  "id": "blog-page",
  "slug": "blog",
  "meta": {
    "title": "Blog — Andrew Linh on Schemas, Types, and Agents",
    "description": "Essays on schema-driven content, end-to-end type safety, AI agent tooling, and developer experience for structured systems."
  },
  "sections": [
    {
      "id": "blog-hero-1",
      "type": "page-hero",
      "data": {
        "label": "Blog",
        "title": "Notes from the seams.",
        "description": "Writing on contracts, type safety, agent evals, and the DX of structured systems."
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "md" }
    },
    {
      "id": "blog-list-1",
      "type": "posts-list",
      "data": {
        "title": "All posts",
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/contact.json << 'EOF'
{
  "id": "contact-page",
  "slug": "contact",
  "meta": {
    "title": "Contact Andrew Linh — Architecture & Writing",
    "description": "Get in touch for systems architecture, schema design, technical writing, and reviews of structured platforms. GitHub, LinkedIn, and blog RSS linked."
  },
  "sections": [
    {
      "id": "contact-hero-1",
      "type": "page-hero",
      "data": {
        "label": "Contact",
        "title": "Say hello.",
        "description": "Architecture reviews, schema design, and technical writing for teams shipping structured platforms."
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "md" }
    },
    {
      "id": "contact-form-1",
      "type": "contact-form",
      "data": {
        "anchorId": "contact",
        "label": "Message",
        "title": "Start a conversation",
        "description": "Prefer email? Use the form. Prefer async social? Links below.",
        "recipientEmail": "hello@andrewlinh.dev",
        "submitLabel": "Send message",
        "successMessage": "Message sent. I will reply soon.",
        "social": [
          { "id": "c-gh", "label": "GitHub", "href": "https://github.com/andrewlinh", "icon": "github" },
          { "id": "c-li", "label": "LinkedIn", "href": "https://linkedin.com/in/andrewlinh", "icon": "linkedin" },
          { "id": "c-rss", "label": "Blog RSS", "href": "/blog/rss.xml", "icon": "rss" },
          { "id": "c-mail", "label": "Email", "href": "mailto:hello@andrewlinh.dev", "icon": "mail" }
        ]
      },
      "settings": { "paddingTop": "md", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/work/\[slug\].json << 'EOF'
{
  "id": "project-detail-page",
  "slug": "work/[slug]",
  "collection": { "source": "projects", "paramKey": "slug" },
  "meta": {
    "title": "Project case study — Andrew Linh",
    "description": "Detailed case study covering context, problem, architecture decisions, measurable results, and technology stack."
  },
  "sections": [
    {
      "id": "project-detail-1",
      "type": "project-detail",
      "data": {
        "item": { "$ref": "collection:current" },
        "backLabel": "Back to work"
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/blog/\[slug\].json << 'EOF'
{
  "id": "post-detail-page",
  "slug": "blog/[slug]",
  "collection": { "source": "posts", "paramKey": "slug" },
  "meta": {
    "title": "Blog post — Andrew Linh",
    "description": "Long-form writing on schema-driven content, type safety, AI agent tooling, and developer experience for structured systems."
  },
  "sections": [
    {
      "id": "post-detail-1",
      "type": "post-detail",
      "data": {
        "item": { "$ref": "collection:current" },
        "backLabel": "Back to blog"
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "lg" }
    }
  ]
}
EOF

# =============================================================================
# STEP 9 — AdminStudioClient wiring check (iconRegistry + collections + collectionSchemas)
# =============================================================================
echo "-- Step 9: checking AdminStudioClient wiring (iconRegistry + collections)..."
ADMIN_CLIENT="src/components/admin/AdminStudioClient.tsx"
if [[ -f "$ADMIN_CLIENT" ]] \
  && grep -q "iconRegistry" "$ADMIN_CLIENT" \
  && grep -q "collectionSchemas" "$ADMIN_CLIENT" \
  && grep -q "collections" "$ADMIN_CLIENT"; then
  echo "   AdminStudioClient wires iconRegistry, collections and collectionSchemas — ok"
else
  echo "!! AdminStudioClient missing iconRegistry / collections / collectionSchemas."
  echo "!! Refusing to guess a patch location. Current wiring found:"
  grep -n "iconRegistry\|collectionSchemas\|collections\|CollectionRegistry\|iconMap" "$ADMIN_CLIENT" 2>/dev/null || true
  echo "!! Manually ensure AdminStudioClient builds JsonPagesConfig with:"
  echo "     iconRegistry: iconMap,                  // import { iconMap } from '@/lib/IconResolver'"
  echo "     collections: <collections data map>,    // e.g. getFileCollections() or explicit JSON imports"
  echo "     collectionSchemas: CollectionRegistry,  // import { CollectionRegistry } from '@/lib/CollectionRegistry'"
  exit 1
fi


# =============================================================================
# POST-PASS — UI polish (shad Button hover+border / typography / pointer)
# =============================================================================
echo "-- Post-pass: shadcn Button + typography + pointer atmosphere..."

mkdir -p src/components/ui src/hooks src/components
rm -f src/components/ui/GradientBorderCta.tsx

# --- shadcn Button (hover + primary border glow; no custom CTA component) ---
cat > src/components/ui/button.tsx << 'EOF'
import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { Slot } from "radix-ui"

import { cn } from "@/lib/utils"

const buttonVariants = cva(
  "inline-flex shrink-0 items-center justify-center gap-1.5 rounded-lg border text-sm font-medium whitespace-nowrap outline-none select-none transition-[color,background-color,border-color,box-shadow] duration-200 focus-visible:ring-3 focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:ring-3 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default:
          "border-primary bg-primary text-primary-foreground hover:bg-primary/85 hover:shadow-[0_0_0_1px_var(--primary),0_0_20px_-4px_var(--primary)]",
        outline:
          "border-border bg-transparent text-foreground hover:border-primary hover:shadow-[0_0_0_1px_var(--primary),0_0_20px_-6px_var(--primary)]",
        secondary:
          "border-secondary bg-secondary text-secondary-foreground hover:bg-secondary/80 hover:border-primary/50",
        ghost:
          "border-transparent bg-transparent hover:bg-muted hover:text-foreground",
        destructive:
          "border-destructive/30 bg-destructive/10 text-destructive hover:bg-destructive/20",
        link:
          "border-transparent text-primary underline-offset-4 hover:underline",
      },
      size: {
        default:
          "h-8 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
        xs: "h-6 gap-1 rounded-[min(var(--radius-md),10px)] px-2 text-xs [&_svg:not([class*='size-'])]:size-3",
        sm: "h-7 gap-1 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem] [&_svg:not([class*='size-'])]:size-3.5",
        lg: "h-9 px-3",
        icon: "size-8",
        "icon-xs": "size-6 rounded-[min(var(--radius-md),10px)] [&_svg:not([class*='size-'])]:size-3",
        "icon-sm": "size-7 rounded-[min(var(--radius-md),12px)]",
        "icon-lg": "size-9",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Button({
  className,
  variant = "default",
  size = "default",
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean
  }) {
  const Comp = asChild ? Slot.Root : "button"

  return (
    <Comp
      data-slot="button"
      data-variant={variant}
      data-size={size}
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Button, buttonVariants }

EOF

# --- Capsules: CTAs use Button ---
cat > src/components/home-hero/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { HomeHeroData, HomeHeroSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const HomeHero: React.FC<{ data: HomeHeroData; settings: HomeHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  return (
    <section
      style={{
        '--local-bg': 'var(--background)',
        '--local-text': 'var(--foreground)',
        '--local-text-muted': 'var(--muted-foreground)',
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-border': 'var(--border)',
        '--local-radius-md': 'var(--theme-radius-md)',
      } as React.CSSProperties}
      className={'relative z-0 overflow-hidden ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="relative z-[1] max-w-3xl jp-animate-in">
          {data.label && (
            <div
              className="mb-6 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]"
              data-jp-field="label"
            >
              <span className="h-px w-5 bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          <h1
            className="font-display text-[clamp(3rem,6vw,5.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]"
            data-jp-field="title"
          >
            {data.title}
            {data.titleHighlight ? (
              <>
                {' '}
                <em className="not-italic text-[var(--local-primary)]" data-jp-field="titleHighlight">
                  {data.titleHighlight}
                </em>
              </>
            ) : null}
          </h1>
          <p className="mt-8 max-w-2xl text-lg text-[var(--local-text-muted)]" data-jp-field="description">
            {data.description}
          </p>
          <div className="mt-10 flex flex-wrap gap-4">
            {data.primaryCta && (
              <Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5">
                <a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a>
              </Button>
            )}
            {data.secondaryCta && (
              <Button asChild variant="outline" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5">
                <a href={data.secondaryCta.href} data-jp-field="secondaryCta">{data.secondaryCta.label}</a>
              </Button>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};

EOF

cat > src/components/bio-band/View.tsx << 'EOF'
// Layout: Hero=A (SPLIT 60/40), Features=E (TABBED)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { BioBandData, BioBandSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const BioBand: React.FC<{ data: BioBandData; settings: BioBandSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="grid items-center gap-12 md:grid-cols-[1.4fr_1fr]">
          <div>
            {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
            <h2 className="font-display text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
            <p className="mt-6 whitespace-pre-line text-base leading-relaxed text-[var(--local-text-muted)]" data-jp-field="body">{data.body}</p>
            {data.cta && (
              <div className="mt-8">
                <Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5">
                  <a href={data.cta.href} data-jp-field="cta">{data.cta.label}</a>
                </Button>
              </div>
            )}
          </div>
          {data.image?.url && <div className="overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]"><img src={data.image.url} alt={data.image.alt || ''} className="aspect-[4/5] w-full object-cover" data-jp-field="image" /></div>}
        </div>
      </div>
    </section>
  );
};

EOF

cat > src/components/cta-band/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=D (ACCORDION)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { CtaBandData, CtaBandSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const CtaBand: React.FC<{ data: CtaBandData; settings: CtaBandSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass + ' text-center'}>
        <h2 className="font-display text-[clamp(3rem,7vw,6.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        {data.description && <p className="mx-auto mt-6 max-w-xl text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
        <div className="mt-10">
          <Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5">
            <a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a>
          </Button>
        </div>
      </div>
    </section>
  );
};

EOF

cat > src/components/contact-form/View.tsx << 'EOF'
'use client';

// Layout: Hero=F (MINIMAL HERO), Features=D (ACCORDION)
import React from 'react';
import { useFormState } from '@olonjs/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Icon } from '@/lib/IconResolver';
import type { ContactFormData, ContactFormSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const ContactForm: React.FC<{ data: ContactFormData; settings: ContactFormSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const formId = data.anchorId?.trim() || 'contact-form';
  const { status, message } = useFormState(formId);
  const socialItems = Array.isArray(data.social) ? data.social : [];
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-md': 'var(--theme-radius-md)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="grid gap-12 md:grid-cols-2">
          <div>
            {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
            <h2 className="font-display text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
            {data.description && <p className="mt-4 text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
            <div className="mt-8 flex flex-col gap-3">
              {socialItems.map((item, idx) => (
                <a key={item.id || 'social-' + idx} href={item.href} target="_blank" rel="noreferrer" data-jp-item-id={item.id || 'social-' + idx} data-jp-item-field="social" className="inline-flex items-center gap-2 text-sm text-[var(--local-text)] hover:text-[var(--local-primary)]"><Icon name={item.icon} size={16} /><span>{item.label}</span></a>
              ))}
            </div>
          </div>
          <form id={formId} data-olon-recipient={data.recipientEmail ?? ''} className="space-y-4 rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6">
            <div><Label htmlFor={formId + '-name'} className="text-[var(--local-text-muted)]">Name</Label><Input id={formId + '-name'} name="name" required className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <div><Label htmlFor={formId + '-email'} className="text-[var(--local-text-muted)]">Email</Label><Input id={formId + '-email'} name="email" type="email" required className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <div><Label htmlFor={formId + '-message'} className="text-[var(--local-text-muted)]">Message</Label><Textarea id={formId + '-message'} name="message" required rows={6} className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <Button type="submit" variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5" data-jp-field="submitLabel">{data.submitLabel}</Button>
            {status === 'success' && <p className="text-sm text-[var(--local-primary)]" data-jp-field="successMessage">{data.successMessage}</p>}
            {status === 'error' && <p className="text-sm text-destructive">{message || 'Something went wrong.'}</p>}
          </form>
        </div>
      </div>
    </section>
  );
};

EOF

cat > src/components/header/View.tsx << 'EOF'
'use client';

// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Button } from '@/components/ui/button';
import { NavigationMenu, NavigationMenuItem, NavigationMenuLink, NavigationMenuList } from '@/components/ui/navigation-menu';
import { Sheet, SheetClose, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { Menu, Moon, Sun } from 'lucide-react';
import type { HeaderData, HeaderSettings } from './types';

export const Header: React.FC<{ data: HeaderData; settings: HeaderSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];
  const [theme, setTheme] = React.useState<'light' | 'dark'>(() => {
    if (typeof document === 'undefined') return 'dark';
    return (document.documentElement.dataset.theme as 'light' | 'dark') || 'dark';
  });
  const toggleTheme = () => {
    const next = theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    setTheme(next);
  };
  return (
    <header style={{ '--local-bg': 'color-mix(in oklch, var(--background) 90%, transparent)', '--local-text': 'var(--foreground)', '--local-border': 'var(--border)', '--local-surface': 'color-mix(in oklch, var(--card) 88%, transparent)', '--local-primary': 'var(--primary)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className="sticky top-0 z-10 border-b border-[var(--local-border)] bg-[var(--local-bg)]/95 backdrop-blur-xl">
      <div className="max-w-[1200px] mx-auto px-8">
        {data.announcement && <div className="border-b border-[var(--local-border)] py-2 text-center text-[0.72rem] font-mono uppercase tracking-[0.16em] text-[var(--local-text)]/70" data-jp-field="announcement">{data.announcement}</div>}
        <div className="flex h-20 items-center justify-between gap-6">
          <a href="/" className="flex items-baseline gap-2">
            <span className="font-display text-2xl tracking-tight text-[var(--local-text)]" data-jp-field="logoText">{data.logoText}</span>
            {data.logoHighlight && <span className="font-mono text-[0.72rem] uppercase tracking-[0.24em] text-[var(--local-primary)]" data-jp-field="logoHighlight">{data.logoHighlight}</span>}
          </a>
          <div className="hidden items-center gap-4 lg:flex">
            <NavigationMenu>
              <NavigationMenuList className="gap-1">
                {navItems.map((item, idx) => (
                  <NavigationMenuItem key={item.id || item.href + '-' + idx} data-jp-item-id={item.id || 'menu-' + idx} data-jp-item-field="menu">
                    <NavigationMenuLink href={item.href} className="rounded-[var(--local-radius-md)] px-4 py-2 text-sm font-medium text-[var(--local-text)] transition hover:bg-[var(--local-surface)]">{item.label}</NavigationMenuLink>
                  </NavigationMenuItem>
                ))}
              </NavigationMenuList>
            </NavigationMenu>
            <Button type="button" variant="outline" size="icon" onClick={toggleTheme} className="rounded-[var(--local-radius-md)]">{theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}</Button>
          </div>
          <div className="flex items-center gap-3 lg:hidden">
            <Button type="button" variant="outline" size="icon" onClick={toggleTheme} className="rounded-[var(--local-radius-md)]">{theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}</Button>
            <Sheet>
              <SheetTrigger asChild><Button variant="outline" size="icon" className="rounded-[var(--local-radius-md)]"><Menu className="h-4 w-4" /></Button></SheetTrigger>
              <SheetContent className="flex flex-col gap-0 bg-card text-foreground">
                <SheetHeader className="border-b border-border px-6 py-5"><SheetTitle className="font-display text-lg text-foreground">{data.logoText || 'Menu'}</SheetTitle></SheetHeader>
                <nav className="flex flex-1 flex-col divide-y divide-border overflow-y-auto">
                  {navItems.map((item, idx) => (
                    <SheetClose asChild key={item.id || item.href + '-m-' + idx}><a href={item.href} className="flex items-center px-6 py-4 text-base font-medium text-foreground hover:bg-muted">{item.label}</a></SheetClose>
                  ))}
                </nav>
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </div>
    </header>
  );
};

EOF

# --- Typography: strip font-black from titles; strip font-bold from h3 ---
echo "   stripping font-black / h3 font-bold..."
find src/components -name 'View.tsx' -print0 | while IFS= read -r -d '' f; do
  sed -i 's/font-display font-black/font-display/g' "$f"
  sed -i 's/\(<h3 className="[^"]*\)font-bold /\1/g' "$f"
done

# Fix jp-animate-in if still stuck at opacity 0
sed -i 's/\.jp-animate-in { opacity: 0; animation: jp-fadeUp 0\.7s ease forwards; }/.jp-animate-in { animation: jp-fadeUp 0.7s ease both; }/g' app/globals.css || true

# --- Pointer field + atmosphere ---
cat > src/hooks/usePointerField.tsx << 'EOF'
'use client';

import { createContext, useContext, useEffect, useMemo, type ReactNode } from 'react';
import { useMotionValue, useSpring, type MotionValue } from 'motion/react';

type PointerFieldValue = {
  x: MotionValue<number>;
  y: MotionValue<number>;
  sx: MotionValue<number>;
  sy: MotionValue<number>;
};

const PointerFieldContext = createContext<PointerFieldValue | null>(null);
const SPRING = { stiffness: 140, damping: 28, mass: 0.6 };

export function PointerFieldProvider({ children }: { children: ReactNode }) {
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const sx = useSpring(x, SPRING);
  const sy = useSpring(y, SPRING);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const onMove = (event: PointerEvent) => {
      x.set(event.clientX);
      y.set(event.clientY);
      document.documentElement.style.setProperty('--pointer-x', event.clientX + 'px');
      document.documentElement.style.setProperty('--pointer-y', event.clientY + 'px');
      document.documentElement.style.setProperty('--pointer-nx', String(event.clientX / window.innerWidth));
      document.documentElement.style.setProperty('--pointer-ny', String(event.clientY / window.innerHeight));
    };
    document.documentElement.style.setProperty('--pointer-active', '1');
    window.addEventListener('pointermove', onMove, { passive: true });
    return () => window.removeEventListener('pointermove', onMove);
  }, [x, y]);

  const value = useMemo(() => ({ x, y, sx, sy }), [x, y, sx, sy]);
  return <PointerFieldContext.Provider value={value}>{children}</PointerFieldContext.Provider>;
}

export function usePointerFieldOptional(): PointerFieldValue | null {
  return useContext(PointerFieldContext);
}
EOF

cat > src/components/PointerAtmosphere.tsx << 'EOF'
'use client';

import { useMotionTemplate, motion, useMotionValue } from 'motion/react';
import { usePointerFieldOptional } from '@/hooks/usePointerField';

export function PointerAtmosphere() {
  const field = usePointerFieldOptional();
  const fallbackX = useMotionValue(0);
  const fallbackY = useMotionValue(0);
  const sx = field?.sx ?? fallbackX;
  const sy = field?.sy ?? fallbackY;
  const glow = useMotionTemplate`radial-gradient(640px circle at ${sx}px ${sy}px, color-mix(in oklch, var(--primary) 12%, transparent), transparent 62%)`;
  if (!field) return null;
  return (
    <motion.div
      aria-hidden
      className="pointer-events-none fixed inset-0 z-0 motion-reduce:hidden"
      style={{ background: glow }}
    />
  );
}
EOF

# --- PointerAtmosphere files written above; Next harness has no App.tsx to patch ---
echo "   PointerField/Atmosphere components written (wire in layout if desired)"

echo "   post-pass complete"

# =============================================================================
# BUILD
# =============================================================================
echo "-- Running npm run build..."
npm run build

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                 SPEC COMPLIANCE CHECKLIST                    ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║ [x] Step 0 shadcn init + components                          ║"
echo "║ [x] Capsules (header/footer + 14 section types)              ║"
echo "║ [x] types.ts module augmentation                             ║"
echo "║ [x] ComponentRegistry 1:1                                    ║"
echo "║ [x] SECTION_SCHEMAS + SUBMISSION_SCHEMAS                     ║"
echo "║ [x] addSectionConfig                                         ║"
echo "║ [x] app/globals.css TOCC + [data-theme=light] + Google Fonts L1 ║"
echo "║ [x] theme.json dark default + light mode                     ║"
echo "║ [x] site.json menu \$ref + menu.json                          ║"
echo "║ [x] Pages: home about work blog contact + detail routes      ║"
echo "║ [x] Collections: projects + posts                            ║"
echo "║ [x] IconResolver (ui:icon-picker)                            ║"
echo "║ [x] Typography: Instrument Sans / Serif / JetBrains Mono     ║"
echo "║ [x] Post-pass: shad Button hover + border glow              ║"
echo "║ [x] Post-pass: pointer components + typography strip           ║"
echo "║ [x] VisitorSection registry-only (no books-list)               ║"
echo "║ [x] AdminStudioClient iconRegistry + collections               ║"
echo "║ [x] npm run build                                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Done. Andrew Linh Next tenant scaffold complete."
