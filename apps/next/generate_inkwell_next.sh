#!/bin/bash
set -e

echo "=============================================================="
echo "  INKWELL JOURNAL — OlonJS Next harness generator"
echo "  Run from the Next tenant root (apps/next or scaffold --template next)"
echo "  No ThemeProvider — light/dark via document.documentElement.dataset.theme"
echo "  Collections + cross-collection relations demo"
echo "  posts -> tags  (post.tags = tag keys)"
echo "  tags  -> posts (resolved at render by filtering posts)"
echo "=============================================================="

# -----------------------------------------------------------------------------
# 0. SHADCN/UI INIT
# -----------------------------------------------------------------------------
echo "-- Step 0: shadcn/ui init..."

# Install shadcn peer dependencies FIRST (shadcn init does NOT do this automatically)
# NOTE: do NOT manually install radix-ui or @radix-ui/react-* — shadcn handles all radix deps
npm install class-variance-authority clsx tailwind-merge lucide-react

# Init shadcn — MUST use new-york style (uses unified 'radix-ui' package)
npx shadcn@latest init --yes --style new-york --base-color slate 2>/dev/null || true

# Install the full component set used by this tenant
npx shadcn@latest add --yes --overwrite \
  button \
  card \
  badge \
  separator \
  avatar \
  table \
  tabs \
  accordion \
  dialog \
  sheet \
  tooltip \
  navigation-menu \
  dropdown-menu \
  hover-card \
  breadcrumb \
  skeleton \
  progress \
  input \
  label \
  textarea \
  select \
  checkbox \
  switch \
  toggle \
  toggle-group \
  scroll-area \
  aspect-ratio

echo "   shadcn/ui components installed"

# -----------------------------------------------------------------------------
# PREFLIGHT — Next App Router layout must exist
# -----------------------------------------------------------------------------
echo "-- Preflight: checking app/layout.tsx..."
if [[ -f app/layout.tsx ]]; then
  echo "   app/layout.tsx found"
else
  echo "!! app/layout.tsx NOT found — run this script from the Next tenant root"
  exit 1
fi

# -----------------------------------------------------------------------------
# DIRECTORIES
# -----------------------------------------------------------------------------
echo "-- Creating directories..."
mkdir -p src/components/header \
         src/components/footer \
         src/components/hero \
         src/components/page-hero \
         src/components/posts-list \
         src/components/tags-list \
         src/components/post-detail \
         src/components/related-tags \
         src/components/tag-detail \
         src/components/tag-posts \
         src/components/content-block \
         src/components/stats-band \
         src/components/cta-banner \
         src/collections/posts \
         src/collections/tags \
         src/data/config \
         src/data/pages \
         src/data/collections/posts \
         src/data/collections/tags \
         src/lib


# -----------------------------------------------------------------------------
# app/globals.css — fonts first line, semantic bridge, light mode, TOCC
# -----------------------------------------------------------------------------
echo "-- Writing app/globals.css..."
cat > app/globals.css << 'EOF'
@import url('https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,400..800&family=Instrument+Sans:ital,wght@0,400..700;1,400..700&family=JetBrains+Mono:wght@400..700&display=swap');
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
  --font-display: var(--theme-font-display, system-ui, sans-serif);
}

:root {
  /* -- Layer 1: semantic bridge ----------------------------- */
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

  /* Theme-derived helpers for section-owned surfaces. */
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

/* -- Layer 1 override: LIGHT mode -------------------------- */
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

.font-display {
  font-family: var(--font-display, var(--font-primary));
}

html { scroll-behavior: smooth; }

/* Animations */
@keyframes jp-fadeUp {
  from { opacity: 0; transform: translateY(20px); }
  to   { opacity: 1; transform: translateY(0); }
}
.jp-animate-in { opacity: 0; animation: jp-fadeUp 0.7s ease forwards; }
.jp-d1 { animation-delay: 0.1s; }
.jp-d2 { animation-delay: 0.2s; }
.jp-d3 { animation-delay: 0.3s; }
.jp-d4 { animation-delay: 0.4s; }

@keyframes jp-pulseDot {
  0%, 100% { opacity: 1; transform: scale(1); }
  50%       { opacity: 0.5; transform: scale(0.85); }
}
.jp-pulse-dot { animation: jp-pulseDot 2s ease infinite; }

/* TOCC — required by §7 spec */
[data-jp-section-overlay] {
  position: absolute; inset: 0; z-index: 9999;
  pointer-events: none; border: 2px solid transparent;
  transition: border-color 0.15s, background-color 0.15s;
}
[data-section-id]:hover [data-jp-section-overlay] {
  border: 2px dashed color-mix(in oklch, var(--primary) 50%, transparent);
  background-color: color-mix(in oklch, var(--primary) 6%, transparent);
}
[data-section-id][data-jp-selected] [data-jp-section-overlay] {
  border: 2px solid var(--primary);
  background-color: color-mix(in oklch, var(--primary) 10%, transparent);
}
[data-jp-section-overlay] > div {
  position: absolute; top: 0; right: 0;
  padding: 0.2rem 0.55rem;
  font-size: 9px; font-weight: 800;
  text-transform: uppercase; letter-spacing: 0.1em;
  background: var(--primary); color: #fff;
  opacity: 0; transition: opacity 0.15s;
}
[data-section-id]:hover [data-jp-section-overlay] > div,
[data-section-id][data-jp-selected] [data-jp-section-overlay] > div { opacity: 1; }

/* Studio inspector — isolate from visitor [data-theme] token leaks on <html> */
aside.bg-zinc-950,
[data-jp-inspector] {
  --foreground: #fafafa;
  color: #fafafa;
}

aside.bg-zinc-950 input,
aside.bg-zinc-950 textarea,
aside.bg-zinc-950 select,
[data-jp-inspector] input,
[data-jp-inspector] textarea,
[data-jp-inspector] select {
  color: #fafafa;
}
EOF

# -----------------------------------------------------------------------------
# COLLECTIONS — posts (COP v1.1)
# -----------------------------------------------------------------------------
echo "-- Writing collection contract: posts..."
cat > src/collections/posts/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseCollectionItem, ImageSelectionSchema } from '@olonjs/core';

export const PostSchema = BaseCollectionItem.extend({
  title: z.string().describe('ui:text'),
  excerpt: z.string().describe('ui:textarea'),
  body: z.string().describe('ui:textarea'),
  image: ImageSelectionSchema.optional(),
  date: z.string().describe('ui:text'),
  author: z.string().describe('ui:text'),
  readingTime: z.string().describe('ui:text'),
  // Relation posts -> tags: each string is a key of the `tags` collection.
  // The relation lives ONLY on the post side (single source of truth);
  // the inverse (tags -> posts) is computed at render time by filtering.
  tags: z.array(z.string()).describe('ui:list'),
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

# -----------------------------------------------------------------------------
# COLLECTIONS — tags (COP v1.1)
# -----------------------------------------------------------------------------
echo "-- Writing collection contract: tags..."
cat > src/collections/tags/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const TagSchema = BaseCollectionItem.extend({
  name: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  accent: z.enum(['primary', 'accent', 'muted']).optional().describe('ui:select'),
});

export const TagsCollectionSchema = z.record(z.string(), TagSchema);
EOF

cat > src/collections/tags/types.ts << 'EOF'
import { z } from 'zod';
import { TagSchema, TagsCollectionSchema } from './schema';

export type Tag = z.infer<typeof TagSchema>;
export type TagsCollection = z.infer<typeof TagsCollectionSchema>;
EOF

cat > src/collections/tags/index.ts << 'EOF'
export { TagSchema, TagsCollectionSchema } from './schema';
export type { Tag, TagsCollection } from './types';
EOF

# -----------------------------------------------------------------------------
# src/lib/CollectionRegistry.ts — one file, every collection source
# -----------------------------------------------------------------------------
echo "-- Writing src/lib/CollectionRegistry.ts..."
cat > src/lib/CollectionRegistry.ts << 'EOF'
import { PostsCollectionSchema } from '@/collections/posts';
import { TagsCollectionSchema } from '@/collections/tags';

export const CollectionRegistry = {
  posts: PostsCollectionSchema,
  tags: TagsCollectionSchema,
} as const;

export type CollectionType = keyof typeof CollectionRegistry;
EOF

# -----------------------------------------------------------------------------
# COLLECTION DATA — keyed objects, collectionKey === entity.id
# -----------------------------------------------------------------------------
echo "-- Writing collection data: posts..."
cat > src/data/collections/posts/posts.json << 'EOF'
{
  "designing-with-constraints": {
    "id": "designing-with-constraints",
    "title": "Designing with constraints, on purpose",
    "excerpt": "Every strong interface we have shipped started with a constraint we refused to negotiate away. Here is how we pick them.",
    "body": "Constraints are not the enemy of good design. They are the only reliable way to make a hundred small decisions coherent with each other. A palette of four colors forces hierarchy; a single display font forces rhythm.\n\nOn Inkwell we hold three constraints fixed: one measure for body text, one accent per surface, and no decoration that does not encode meaning. Everything else is allowed to move.\n\nThe result is not austerity. It is that rare feeling of a page where nothing competes with the words.",
    "image": { "url": "https://images.unsplash.com/photo-1455390582262-044cdead277a?w=1600&q=80", "alt": "Fountain pen resting on a notebook with handwritten notes" },
    "date": "2026-06-28",
    "author": "June Park",
    "readingTime": "6 min",
    "tags": ["design", "process"]
  },
  "the-boring-stack": {
    "id": "the-boring-stack",
    "title": "The boring stack is a feature",
    "excerpt": "We rebuilt our pipeline on tools nobody tweets about. Deploys got faster and the on-call channel went quiet.",
    "body": "There is a special kind of silence that follows choosing boring technology. The pager stops. The changelog reads like a grocery list. Nobody has to relearn the build system on a Tuesday.\n\nBoring does not mean old. It means the failure modes are documented, the upgrade path is known, and the second engineer to touch the code can predict what the first one did.\n\nWe budget our novelty. One genuinely new tool per quarter, everything else deliberately dull. That budget is the most productive constraint we have.",
    "image": { "url": "https://images.unsplash.com/photo-1518770660439-4636190af475?w=1600&q=80", "alt": "Close-up of a circuit board with soldered components" },
    "date": "2026-06-19",
    "author": "Tomas Lindgren",
    "readingTime": "5 min",
    "tags": ["engineering", "tooling"]
  },
  "write-the-readme-first": {
    "id": "write-the-readme-first",
    "title": "Write the README first",
    "excerpt": "If you cannot explain the tool before building it, you are about to build the wrong tool. A practice we stole from technical writers.",
    "body": "Before any code exists, we write the README as if the project were finished: what it does, how you install it, the three commands you will actually use. It takes an hour and it kills bad ideas while they are still cheap.\n\nThe README-first draft exposes the seams. If the usage section needs four paragraphs of caveats, the interface is wrong. If the install steps require a diagram, the packaging is wrong.\n\nDocumentation is not what you write after the work. Often, it is the work.",
    "image": { "url": "https://images.unsplash.com/photo-1517842645767-c639042777db?w=1600&q=80", "alt": "Open notebook with a pen on a wooden desk beside a laptop" },
    "date": "2026-06-10",
    "author": "Ada Osei",
    "readingTime": "4 min",
    "tags": ["writing", "process"]
  },
  "tokens-not-pixels": {
    "id": "tokens-not-pixels",
    "title": "Tokens, not pixels",
    "excerpt": "The day we deleted every hardcoded hex value was the day dark mode became a data change instead of a rewrite.",
    "body": "A design token is a promise: this value has a name, the name has a meaning, and the meaning survives a redesign. A hex code in a component is the opposite — a decision nobody can find later.\n\nOur rule is mechanical. Components consume semantic variables; variables resolve from a theme document; the theme document is data. Light mode, dark mode, a client rebrand: all of them become edits to one JSON file.\n\nIt is the least glamorous migration we ever ran, and the one with the highest return. Every surface in this journal, including the one you are reading, is painted through that chain.",
    "image": { "url": "https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=1600&q=80", "alt": "Monitor showing colorful code in a dark editor theme" },
    "date": "2026-05-30",
    "author": "June Park",
    "readingTime": "7 min",
    "tags": ["design", "engineering", "tooling"]
  },
  "shipping-on-fridays": {
    "id": "shipping-on-fridays",
    "title": "Yes, we ship on Fridays",
    "excerpt": "The no-Friday-deploy rule treats the symptom. We fixed the disease instead, and the weekend stayed quiet anyway.",
    "body": "Teams that fear Friday deploys do not have a calendar problem, they have a confidence problem. The fix is not a freeze window; it is making deploys so small and so reversible that the day of the week stops mattering.\n\nWe ship changes measured in tens of lines, behind flags, with a rollback that takes one command and no meeting. When a deploy is that cheap, Friday afternoon is just another afternoon.\n\nThe cultural shift matters more than the tooling: nobody gets praised here for a heroic weekend fix. We praise the boring deploy that nobody noticed.",
    "image": { "url": "https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=1600&q=80", "alt": "Laptop and coffee cup on a tidy desk in warm morning light" },
    "date": "2026-05-18",
    "author": "Marco Bellini",
    "readingTime": "5 min",
    "tags": ["culture", "process"]
  },
  "notes-on-code-review": {
    "id": "notes-on-code-review",
    "title": "Code review is a writing exercise",
    "excerpt": "The best reviewers on our team are not the fastest readers of code. They are the most careful writers of comments.",
    "body": "A review comment is a tiny piece of technical writing with a hostile audience: a tired author who wants to merge. Precision and kindness are not in tension there — they are the same skill.\n\nWe rewrote our review guidelines around sentences, not checklists. Say what you observed, say why it matters, say what you would accept. Three sentences, no verdicts without reasons.\n\nReview latency dropped by half. Not because people read faster, but because nobody has to decode what a one-word comment meant.",
    "image": { "url": "https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=1600&q=80", "alt": "Two colleagues discussing work in front of a shared screen" },
    "date": "2026-05-04",
    "author": "Ada Osei",
    "readingTime": "6 min",
    "tags": ["engineering", "culture"]
  },
  "the-second-draft": {
    "id": "the-second-draft",
    "title": "The second draft is the real one",
    "excerpt": "Everything on this journal is published twice: once to find out what we think, once to say it properly.",
    "body": "First drafts are for discovering the argument. They meander, they hedge, they bury the point in paragraph four. That is fine — their job is excavation, not presentation.\n\nThe second draft starts from one question: what is the single sentence this piece exists to deliver? Everything that does not serve that sentence gets cut, no matter how much we liked writing it.\n\nOur average post loses forty percent of its words between drafts. Readers never miss them.",
    "image": { "url": "https://images.unsplash.com/photo-1455390582262-044cdead277a?w=1600&q=80", "alt": "Handwritten manuscript pages with edits and crossed-out lines" },
    "date": "2026-04-22",
    "author": "June Park",
    "readingTime": "4 min",
    "tags": ["writing"]
  },
  "tools-that-disappear": {
    "id": "tools-that-disappear",
    "title": "Good tools disappear",
    "excerpt": "The highest compliment for a tool is that nobody remembers using it. On interfaces that get out of the way.",
    "body": "You do not think about a doorknob when you open a door. That is the standard: a tool succeeded when the person forgot it was there and remembers only the work.\n\nEvery affordance we add is tested against one question — does this move attention toward the content or toward the chrome? Toolbars lost that argument here more than once.\n\nInvisible does not mean minimal for its own sake. It means every visible element earns its place by carrying meaning the content cannot carry alone.",
    "image": { "url": "https://images.unsplash.com/photo-1497032628192-86f99bcd76bc?w=1600&q=80", "alt": "Minimal workspace with a laptop, plant and empty desk surface" },
    "date": "2026-04-09",
    "author": "Tomas Lindgren",
    "readingTime": "5 min",
    "tags": ["tooling", "design"]
  }
}
EOF

echo "-- Writing collection data: tags..."
cat > src/data/collections/tags/tags.json << 'EOF'
{
  "design": {
    "id": "design",
    "name": "Design",
    "description": "Interfaces, typography, tokens and the discipline of visual decisions that survive a redesign.",
    "accent": "primary"
  },
  "engineering": {
    "id": "engineering",
    "name": "Engineering",
    "description": "Building software that stays boring in production: architecture, reliability and the craft of the diff.",
    "accent": "accent"
  },
  "process": {
    "id": "process",
    "name": "Process",
    "description": "How work actually gets shipped — constraints, drafts, deploys and the rituals that keep teams honest.",
    "accent": "primary"
  },
  "writing": {
    "id": "writing",
    "name": "Writing",
    "description": "Technical writing as a first-class engineering skill: READMEs, review comments, and second drafts.",
    "accent": "muted"
  },
  "tooling": {
    "id": "tooling",
    "name": "Tooling",
    "description": "The instruments of the trade — editors, pipelines, build systems — and when they should disappear.",
    "accent": "accent"
  },
  "culture": {
    "id": "culture",
    "name": "Culture",
    "description": "The habits behind the code: quiet deploys, kind reviews, and praising the fix nobody noticed.",
    "accent": "muted"
  }
}
EOF

# -----------------------------------------------------------------------------
# CAPSULE: header
# -----------------------------------------------------------------------------
echo "-- Writing capsule: header..."
cat > src/components/header/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const HeaderMenuItemSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  isCta: z.boolean().optional().describe('ui:checkbox'),
});

export const HeaderSchema = BaseSectionData.extend({
  logoText: z.string().describe('ui:text'),
  logoHighlight: z.string().optional().describe('ui:text'),
  announcement: z.string().optional().describe('ui:text'),
  // Resolved editing surface: site.json authors data.menu as a $ref to
  // menu.json; the engine resolves it before the Inspector sees it.
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

import React from 'react';
import { Button } from '@/components/ui/button';
import {
  NavigationMenu,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList,
} from '@/components/ui/navigation-menu';
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
    <header
      style={{
        '--local-bg': 'color-mix(in oklch, var(--background) 90%, transparent)',
        '--local-text': 'var(--foreground)',
        '--local-border': 'var(--border)',
        '--local-surface': 'color-mix(in oklch, var(--card) 88%, transparent)',
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className="sticky top-0 z-10 border-b border-[var(--local-border)] bg-[var(--local-bg)]/95 backdrop-blur-xl"
    >
      <div className="max-w-[1200px] mx-auto px-8">
        {data.announcement && (
          <div
            className="border-b border-[var(--local-border)] py-2 text-center text-[0.72rem] font-mono uppercase tracking-[0.16em] text-[var(--local-text)]/70"
            data-jp-field="announcement"
          >
            {data.announcement}
          </div>
        )}
        <div className="flex h-20 items-center justify-between gap-6">
          <a href="/" className="flex items-baseline gap-2">
            <span className="font-display text-2xl font-black tracking-tight text-[var(--local-text)]" data-jp-field="logoText">
              {data.logoText}
            </span>
            {data.logoHighlight && (
              <span className="font-mono text-[0.72rem] uppercase tracking-[0.24em] text-[var(--local-primary)]" data-jp-field="logoHighlight">
                {data.logoHighlight}
              </span>
            )}
          </a>

          <div className="hidden items-center gap-4 lg:flex">
            <NavigationMenu>
              <NavigationMenuList className="gap-1">
                {navItems.map((item, idx) => (
                  <NavigationMenuItem
                    key={item.id || `${item.href}-${idx}`}
                    data-jp-item-id={item.id || `menu-${idx}`}
                    data-jp-item-field="menu"
                  >
                    <NavigationMenuLink
                      href={item.href}
                      className={
                        item.isCta
                          ? 'rounded-[var(--local-radius-md)] bg-[var(--local-primary)] px-4 py-2 text-sm font-semibold text-[var(--local-primary-foreground)] transition hover:opacity-90'
                          : 'rounded-[var(--local-radius-md)] px-4 py-2 text-sm font-medium text-[var(--local-text)] transition hover:bg-[var(--local-surface)]'
                      }
                    >
                      {item.label}
                    </NavigationMenuLink>
                  </NavigationMenuItem>
                ))}
              </NavigationMenuList>
            </NavigationMenu>
            <Button
              type="button"
              variant="outline"
              onClick={toggleTheme}
              className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
            >
              {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </Button>
          </div>

          <div className="flex items-center gap-3 lg:hidden">
            <Button
              type="button"
              variant="outline"
              onClick={toggleTheme}
              className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
            >
              {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </Button>
            <Sheet>
              <SheetTrigger asChild>
                <Button variant="outline" className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]">
                  <Menu className="h-4 w-4" />
                </Button>
              </SheetTrigger>
              <SheetContent className="flex flex-col gap-0 bg-card text-foreground">
                <SheetHeader className="border-b border-border px-6 py-5">
                  <SheetTitle className="font-display text-lg text-foreground">{data.logoText || 'Menu'}</SheetTitle>
                </SheetHeader>
                <nav className="flex flex-1 flex-col divide-y divide-border overflow-y-auto">
                  {/* Mobile duplicate of navItems: intentionally NOT carrying
                      data-jp-item-id/data-jp-item-field — the desktop list is
                      the canonical IDAC-bound instance. */}
                  {navItems.map((item, idx) => (
                    <SheetClose asChild key={item.id || `${item.href}-mobile-${idx}`}>
                      <a
                        href={item.href}
                        className="flex items-center px-6 py-4 text-base font-medium text-foreground transition hover:bg-muted active:bg-muted"
                      >
                        {item.label}
                      </a>
                    </SheetClose>
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

# -----------------------------------------------------------------------------
# CAPSULE: footer
# -----------------------------------------------------------------------------
echo "-- Writing capsule: footer..."
cat > src/components/footer/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const FooterMenuItemSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
});

export const FooterSchema = BaseSectionData.extend({
  brandText: z.string().describe('ui:text'),
  tagline: z.string().optional().describe('ui:textarea'),
  email: z.string().optional().describe('ui:text'),
  copyright: z.string().describe('ui:text'),
  menu: z.array(FooterMenuItemSchema).optional().describe('ui:list'),
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
import React from 'react';
import { Separator } from '@/components/ui/separator';
import type { FooterData, FooterSettings } from './types';

export const Footer: React.FC<{ data: FooterData; settings: FooterSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];

  return (
    <footer
      style={{
        '--local-bg': 'var(--background)',
        '--local-text': 'var(--foreground)',
        '--local-text-muted': 'var(--muted-foreground)',
        '--local-border': 'var(--border)',
        '--local-primary': 'var(--primary)',
      } as React.CSSProperties}
      className="relative z-0 border-t border-[var(--local-border)] bg-[var(--local-bg)] py-20"
    >
      <div className="max-w-[1200px] mx-auto px-8">
        <div className="grid gap-12 md:grid-cols-3">
          <div>
            <span className="font-display text-2xl font-black tracking-tight text-[var(--local-text)]" data-jp-field="brandText">
              {data.brandText}
            </span>
            {data.tagline && (
              <p className="mt-3 max-w-xs text-sm leading-relaxed text-[var(--local-text-muted)]" data-jp-field="tagline">
                {data.tagline}
              </p>
            )}
          </div>
          <nav aria-label="Footer">
            <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em] text-[var(--local-text)]">Explore</h3>
            <ul className="mt-4 space-y-2">
              {navItems.map((item, idx) => (
                <li key={item.id || `menu-${idx}`} data-jp-item-id={item.id || `menu-${idx}`} data-jp-item-field="menu">
                  <a href={item.href} className="text-sm text-[var(--local-text-muted)] transition hover:text-[var(--local-primary)]">
                    {item.label}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
          <div>
            <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em] text-[var(--local-text)]">Contact</h3>
            {data.email && (
              <a
                href={'mailto:' + data.email}
                className="mt-4 inline-block text-sm text-[var(--local-text-muted)] transition hover:text-[var(--local-primary)]"
                data-jp-field="email"
              >
                {data.email}
              </a>
            )}
          </div>
        </div>
        <Separator className="my-10 bg-[var(--local-border)]" />
        <p className="text-xs text-[var(--local-text-muted)]" data-jp-field="copyright">
          {data.copyright}
        </p>
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

# -----------------------------------------------------------------------------
# CAPSULE: hero
# -----------------------------------------------------------------------------
echo "-- Writing capsule: hero..."
cat > src/components/hero/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema, ImageSelectionSchema } from '@olonjs/core';

export const HeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  titleHighlight: z.string().optional().describe('ui:text'),
  subtitle: z.string().describe('ui:textarea'),
  primaryCta: CtaSchema,
  secondaryCta: CtaSchema.optional(),
  image: ImageSelectionSchema.optional(),
});
EOF

cat > src/components/hero/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { HeroSchema } from './schema';

export type HeroData = z.infer<typeof HeroSchema>;
export type HeroSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/hero/View.tsx << 'EOF'
// Layout: Hero=D (EDITORIAL), Features=A (BENTO) on home + C (TIMELINE) on posts index
import React from 'react';
import { Button } from '@/components/ui/button';
import { AspectRatio } from '@/components/ui/aspect-ratio';
import type { HeroData, HeroSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const Hero: React.FC<{ data: HeroData; settings: HeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-accent': 'var(--accent)',
        '--local-accent-soft': 'var(--demo-accent-soft)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-md': 'var(--theme-radius-md)',
      } as React.CSSProperties}
      className={`relative z-0 overflow-hidden ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[1100px] h-[650px] bg-[radial-gradient(ellipse_at_50%_0%,var(--local-accent-soft),transparent_65%)] pointer-events-none" />
      <div className={containerClass}>
        {data.label && (
          <div
            className="jp-animate-in inline-flex items-center gap-2 bg-[var(--local-accent-soft)] border border-[var(--local-border)] px-4 py-1.5 rounded-full text-[0.70rem] font-mono font-semibold text-[var(--local-accent)] tracking-widest uppercase"
            data-jp-field="label"
          >
            <span className="w-1.5 h-1.5 rounded-full bg-[var(--local-primary)] jp-pulse-dot" />
            {data.label}
          </div>
        )}
        <h1
          className="jp-animate-in jp-d1 mt-8 max-w-[16ch] font-display font-black text-[clamp(3rem,6vw,5.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]"
          data-jp-field="title"
        >
          {data.title}{' '}
          {data.titleHighlight && (
            <em className="not-italic bg-gradient-to-br from-[var(--local-primary)] to-[var(--local-accent)] bg-clip-text text-transparent" data-jp-field="titleHighlight">
              {data.titleHighlight}
            </em>
          )}
        </h1>
        <p className="jp-animate-in jp-d2 mt-8 max-w-[52ch] text-lg leading-relaxed text-[var(--local-text-muted)]" data-jp-field="subtitle">
          {data.subtitle}
        </p>
        <div className="jp-animate-in jp-d3 mt-10 flex flex-wrap items-center gap-4">
          <Button
            asChild
            variant="default"
            size="lg"
            className="rounded-[var(--local-radius-md)] bg-[var(--local-primary)] text-[var(--local-primary-foreground)] hover:opacity-90"
          >
            <a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a>
          </Button>
          {data.secondaryCta && (
            <Button
              asChild
              variant="outline"
              size="lg"
              className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-transparent text-[var(--local-text)] hover:border-[var(--local-accent)]"
            >
              <a href={data.secondaryCta.href} data-jp-field="secondaryCta">{data.secondaryCta.label}</a>
            </Button>
          )}
        </div>
      </div>
      {data.image?.url && (
        <div className="jp-animate-in jp-d4 relative left-1/2 mt-16 w-screen -translate-x-1/2">
          <AspectRatio ratio={21 / 9}>
            <img src={data.image.url} alt={data.image.alt || ''} className="h-full w-full object-cover" />
          </AspectRatio>
        </div>
      )}
    </section>
  );
};
EOF

cat > src/components/hero/index.ts << 'EOF'
export { Hero } from './View';
export { HeroSchema } from './schema';
export type { HeroData, HeroSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: page-hero
# -----------------------------------------------------------------------------
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
import React from 'react';
import type { PageHeroData, PageHeroSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const PageHero: React.FC<{ data: PageHeroData; settings: PageHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
      } as React.CSSProperties}
      className={`relative z-0 border-b border-[var(--local-border)] ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.label && (
          <div
            className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
            data-jp-field="label"
          >
            <span className="w-5 h-px bg-[var(--local-primary)]" />
            {data.label}
          </div>
        )}
        <h1 className="font-display font-black text-[clamp(2.4rem,5vw,4.2rem)] leading-[1.02] tracking-tight text-[var(--local-text)]" data-jp-field="title">
          {data.title}
        </h1>
        {data.description && (
          <p className="mt-6 max-w-[56ch] text-lg leading-relaxed text-[var(--local-text-muted)]" data-jp-field="description">
            {data.description}
          </p>
        )}
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

# -----------------------------------------------------------------------------
# CAPSULE: posts-list (listing capsule — binds the full posts collection)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: posts-list..."
cat > src/components/posts-list/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';

export const PostsListSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  variant: z.enum(['bento', 'timeline']).optional().describe('ui:select'),
  limit: z.number().optional().describe('ui:number'),
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
// Layout: Features=A (BENTO) default variant, C (TIMELINE) alternative variant
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { PostsListData, PostsListSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const PostsList: React.FC<{ data: PostsListData; settings: PostsListSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  const posts = Object.values(data.items ?? {}).sort((a, b) => (b.date || '').localeCompare(a.date || ''));
  const visible = data.limit ? posts.slice(0, data.limit) : posts;
  const variant = data.variant ?? 'bento';

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.label && (
          <div
            className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
            data-jp-field="label"
          >
            <span className="w-5 h-px bg-[var(--local-primary)]" />
            {data.label}
          </div>
        )}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
          {data.title}
        </h2>
        {data.description && (
          <p className="mt-4 max-w-[56ch] text-base leading-relaxed text-[var(--local-text-muted)]" data-jp-field="description">
            {data.description}
          </p>
        )}

        {variant === 'timeline' ? (
          <div className="mt-12 border-l border-[var(--local-border)] pl-8">
            {visible.map((post, idx) => (
              <a
                key={post.id || `legacy-${idx}`}
                href={'/posts/' + (post.id || '')}
                className="group relative block pb-12 last:pb-0"
                data-jp-item-id={post.id || `legacy-${idx}`}
                data-jp-item-field="items"
              >
                <span className="absolute -left-[37px] top-1.5 h-2.5 w-2.5 rounded-full border border-[var(--local-border)] bg-[var(--local-primary)]" />
                <div className="font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)]">
                  {post.date} · {post.author} · {post.readingTime}
                </div>
                <h3 className="mt-2 font-display text-[1.4rem] font-bold leading-tight tracking-tight text-[var(--local-text)] transition group-hover:text-[var(--local-primary)]">
                  {post.title}
                </h3>
                <p className="mt-2 max-w-[64ch] text-sm leading-relaxed text-[var(--local-text-muted)]">{post.excerpt}</p>
                <div className="mt-3 flex flex-wrap gap-2">
                  {post.tags.map((tagId) => (
                    <span key={tagId} className="font-mono text-[0.65rem] uppercase tracking-widest text-[var(--local-accent)]">
                      #{tagId}
                    </span>
                  ))}
                </div>
              </a>
            ))}
          </div>
        ) : (
          <div className="mt-12 grid gap-6 md:grid-cols-6">
            {visible.map((post, idx) => (
              <a
                key={post.id || `legacy-${idx}`}
                href={'/posts/' + (post.id || '')}
                className={(idx === 0 ? 'md:col-span-4' : 'md:col-span-2') + ' group'}
                data-jp-item-id={post.id || `legacy-${idx}`}
                data-jp-item-field="items"
              >
                <Card className="h-full overflow-hidden rounded-[var(--local-radius-lg)] border-[var(--local-border)] bg-[var(--local-surface)] py-0 transition group-hover:border-[var(--local-accent)]">
                  {post.image?.url && (
                    <div className={idx === 0 ? 'h-64 overflow-hidden' : 'h-40 overflow-hidden'}>
                      <img
                        src={post.image.url}
                        alt={post.image.alt || ''}
                        className="h-full w-full object-cover transition duration-500 group-hover:scale-[1.03]"
                      />
                    </div>
                  )}
                  <CardContent className="p-6">
                    <div className="font-mono text-[0.68rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)]">
                      {post.date} · {post.readingTime}
                    </div>
                    <h3 className="mt-2 font-display text-[1.2rem] font-bold leading-tight tracking-tight text-[var(--local-text)]">
                      {post.title}
                    </h3>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--local-text-muted)]">{post.excerpt}</p>
                    <div className="mt-4 flex flex-wrap gap-2">
                      {post.tags.map((tagId) => (
                        <span key={tagId} className="font-mono text-[0.65rem] uppercase tracking-widest text-[var(--local-accent)]">
                          #{tagId}
                        </span>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              </a>
            ))}
          </div>
        )}
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

# -----------------------------------------------------------------------------
# CAPSULE: tags-list (listing capsule — binds the full tags collection)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: tags-list..."
cat > src/components/tags-list/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { TagSchema } from '@/collections/tags';

export const TagsListSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), TagSchema).describe('ui:collection-ref'),
});
EOF

cat > src/components/tags-list/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { TagsListSchema } from './schema';

export type TagsListData = z.infer<typeof TagsListSchema>;
export type TagsListSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/tags-list/View.tsx << 'EOF'
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { TagsListData, TagsListSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

const ACCENT_VAR: Record<string, string> = {
  primary: 'var(--local-primary)',
  accent: 'var(--local-accent)',
  muted: 'var(--local-text-muted)',
};

export const TagsList: React.FC<{ data: TagsListData; settings: TagsListSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  const tags = Object.values(data.items ?? {});

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.label && (
          <div
            className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
            data-jp-field="label"
          >
            <span className="w-5 h-px bg-[var(--local-primary)]" />
            {data.label}
          </div>
        )}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
          {data.title}
        </h2>
        {data.description && (
          <p className="mt-4 max-w-[56ch] text-base leading-relaxed text-[var(--local-text-muted)]" data-jp-field="description">
            {data.description}
          </p>
        )}
        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {tags.map((tag, idx) => (
            <a
              key={tag.id || `legacy-${idx}`}
              href={'/tags/' + (tag.id || '')}
              className="group"
              data-jp-item-id={tag.id || `legacy-${idx}`}
              data-jp-item-field="items"
            >
              <Card className="h-full rounded-[var(--local-radius-lg)] border-[var(--local-border)] bg-[var(--local-surface)] transition group-hover:border-[var(--local-accent)]">
                <CardContent className="p-6">
                  <span
                    className="font-mono text-[0.7rem] font-semibold uppercase tracking-[0.2em]"
                    style={{ color: ACCENT_VAR[tag.accent ?? 'primary'] }}
                  >
                    #{tag.id}
                  </span>
                  <h3 className="mt-3 font-display text-[1.2rem] font-bold leading-tight tracking-tight text-[var(--local-text)]">
                    {tag.name}
                  </h3>
                  <p className="mt-2 text-sm leading-relaxed text-[var(--local-text-muted)]">{tag.description}</p>
                </CardContent>
              </Card>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/tags-list/index.ts << 'EOF'
export { TagsList } from './View';
export { TagsListSchema } from './schema';
export type { TagsListData, TagsListSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: post-detail (detail capsule — binds the route-selected post)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: post-detail..."
cat > src/components/post-detail/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';

export const PostDetailSchema = BaseSectionData.extend({
  backLabel: z.string().optional().describe('ui:text'),
  item: PostSchema.describe('ui:collection-ref'),
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
import React from 'react';
import { ArrowLeft } from 'lucide-react';
import { AspectRatio } from '@/components/ui/aspect-ratio';
import type { PostDetailData, PostDetailSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const PostDetail: React.FC<{ data: PostDetailData; settings: PostDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  const post = data.item;
  const paragraphs = (post.body || '').split('\n\n');

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        <div className="mx-auto max-w-[760px]">
          {data.backLabel && (
            <a
              href="/posts"
              className="inline-flex items-center gap-2 font-mono text-[0.72rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)] transition hover:text-[var(--local-primary)]"
              data-jp-field="backLabel"
            >
              <ArrowLeft className="h-3.5 w-3.5" />
              {data.backLabel}
            </a>
          )}
          <div className="mt-6 font-mono text-[0.72rem] uppercase tracking-[0.16em] text-[var(--local-accent)]">
            <span data-jp-field="item.date">{post.date}</span>
            <span className="mx-2 text-[var(--local-text-muted)]">·</span>
            <span data-jp-field="item.author">{post.author}</span>
            <span className="mx-2 text-[var(--local-text-muted)]">·</span>
            <span data-jp-field="item.readingTime">{post.readingTime}</span>
          </div>
          <h1
            className="mt-4 font-display font-black text-[clamp(2.4rem,5vw,4rem)] leading-[1.02] tracking-tight text-[var(--local-text)]"
            data-jp-field="item.title"
          >
            {post.title}
          </h1>
          <p className="mt-6 text-xl leading-relaxed text-[var(--local-text-muted)]" data-jp-field="item.excerpt">
            {post.excerpt}
          </p>
        </div>
        {post.image?.url && (
          <div className="mx-auto mt-12 max-w-[980px] overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]">
            <AspectRatio ratio={21 / 9}>
              <img src={post.image.url} alt={post.image.alt || ''} className="h-full w-full object-cover" />
            </AspectRatio>
          </div>
        )}
        <div className="mx-auto mt-12 max-w-[680px]" data-jp-field="item.body">
          {paragraphs.map((paragraph, idx) => (
            <p key={idx} className="mb-6 text-base leading-[1.85] text-[var(--local-text)]/90">
              {paragraph}
            </p>
          ))}
        </div>
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

# -----------------------------------------------------------------------------
# CAPSULE: related-tags (RELATION post -> tags, resolved at render time)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: related-tags..."
cat > src/components/related-tags/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';
import { TagSchema } from '@/collections/tags';

// Dual binding: `item` is the route-selected post (collection:current),
// `tags` is the FULL foreign collection. The View resolves the relation
// post.tags (array of tag keys) against the tags map.
export const RelatedTagsSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().optional().describe('ui:text'),
  emptyLabel: z.string().optional().describe('ui:text'),
  item: PostSchema.describe('ui:collection-ref'),
  tags: z.record(z.string(), TagSchema).describe('ui:collection-ref'),
});
EOF

cat > src/components/related-tags/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { RelatedTagsSchema } from './schema';

export type RelatedTagsData = z.infer<typeof RelatedTagsSchema>;
export type RelatedTagsSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/related-tags/View.tsx << 'EOF'
import React from 'react';
import type { Tag } from '@/collections/tags';
import type { RelatedTagsData, RelatedTagsSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

const ACCENT_VAR: Record<string, string> = {
  primary: 'var(--local-primary)',
  accent: 'var(--local-accent)',
  muted: 'var(--local-text-muted)',
};

export const RelatedTags: React.FC<{ data: RelatedTagsData; settings: RelatedTagsSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  // Relation resolution: post.tags is an array of tag collection keys.
  const tagMap = data.tags ?? {};
  const related = (data.item.tags ?? [])
    .map((tagId) => tagMap[tagId])
    .filter((tag): tag is Tag => Boolean(tag));

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-md': 'var(--theme-radius-md)',
      } as React.CSSProperties}
      className={`relative z-0 border-t border-[var(--local-border)] ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        <div className="mx-auto max-w-[760px]">
          {data.label && (
            <div
              className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
              data-jp-field="label"
            >
              <span className="w-5 h-px bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          {data.title && (
            <h2 className="font-display text-[1.4rem] font-bold leading-tight tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
          )}
          {related.length > 0 ? (
            <div className="mt-6 flex flex-wrap gap-3">
              {related.map((tag, idx) => (
                <a
                  key={tag.id || `legacy-${idx}`}
                  href={'/tags/' + (tag.id || '')}
                  className="group inline-flex items-center gap-2 rounded-[var(--local-radius-md)] border border-[var(--local-border)] bg-[var(--local-surface)] px-4 py-2 transition hover:border-[var(--local-accent)]"
                >
                  <span
                    className="font-mono text-[0.7rem] font-semibold uppercase tracking-[0.18em]"
                    style={{ color: ACCENT_VAR[tag.accent ?? 'primary'] }}
                  >
                    #{tag.id}
                  </span>
                  <span className="text-sm font-medium text-[var(--local-text)] transition group-hover:text-[var(--local-primary)]">
                    {tag.name}
                  </span>
                </a>
              ))}
            </div>
          ) : (
            data.emptyLabel && (
              <p className="mt-6 text-sm text-[var(--local-text-muted)]" data-jp-field="emptyLabel">
                {data.emptyLabel}
              </p>
            )
          )}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/related-tags/index.ts << 'EOF'
export { RelatedTags } from './View';
export { RelatedTagsSchema } from './schema';
export type { RelatedTagsData, RelatedTagsSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: tag-detail (detail capsule — binds the route-selected tag)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: tag-detail..."
cat > src/components/tag-detail/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { TagSchema } from '@/collections/tags';

export const TagDetailSchema = BaseSectionData.extend({
  backLabel: z.string().optional().describe('ui:text'),
  item: TagSchema.describe('ui:collection-ref'),
});
EOF

cat > src/components/tag-detail/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { TagDetailSchema } from './schema';

export type TagDetailData = z.infer<typeof TagDetailSchema>;
export type TagDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/tag-detail/View.tsx << 'EOF'
import React from 'react';
import { ArrowLeft } from 'lucide-react';
import type { TagDetailData, TagDetailSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const TagDetail: React.FC<{ data: TagDetailData; settings: TagDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  const tag = data.item;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
      } as React.CSSProperties}
      className={`relative z-0 border-b border-[var(--local-border)] ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.backLabel && (
          <a
            href="/tags"
            className="inline-flex items-center gap-2 font-mono text-[0.72rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)] transition hover:text-[var(--local-primary)]"
            data-jp-field="backLabel"
          >
            <ArrowLeft className="h-3.5 w-3.5" />
            {data.backLabel}
          </a>
        )}
        <div className="mt-6 font-mono text-[0.78rem] font-semibold uppercase tracking-[0.22em] text-[var(--local-accent)]">
          #{tag.id}
        </div>
        <h1
          className="mt-3 font-display font-black text-[clamp(2.4rem,5vw,4.2rem)] leading-[1.02] tracking-tight text-[var(--local-text)]"
          data-jp-field="item.name"
        >
          {tag.name}
        </h1>
        <p className="mt-6 max-w-[56ch] text-lg leading-relaxed text-[var(--local-text-muted)]" data-jp-field="item.description">
          {tag.description}
        </p>
      </div>
    </section>
  );
};
EOF

cat > src/components/tag-detail/index.ts << 'EOF'
export { TagDetail } from './View';
export { TagDetailSchema } from './schema';
export type { TagDetailData, TagDetailSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: tag-posts (RELATION tag -> posts, inverse relation computed at render)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: tag-posts..."
cat > src/components/tag-posts/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';
import { TagSchema } from '@/collections/tags';

// Dual binding: `item` is the route-selected tag (collection:current),
// `posts` is the FULL posts collection. The inverse relation tag -> posts is
// never stored in data: it is computed here by filtering posts whose
// `tags` array contains the current tag key.
export const TagPostsSchema = BaseSectionData.extend({
  title: z.string().optional().describe('ui:text'),
  emptyLabel: z.string().optional().describe('ui:text'),
  item: TagSchema.describe('ui:collection-ref'),
  posts: z.record(z.string(), PostSchema).describe('ui:collection-ref'),
});
EOF

cat > src/components/tag-posts/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { TagPostsSchema } from './schema';

export type TagPostsData = z.infer<typeof TagPostsSchema>;
export type TagPostsSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/tag-posts/View.tsx << 'EOF'
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { TagPostsData, TagPostsSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const TagPosts: React.FC<{ data: TagPostsData; settings: TagPostsSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  // Inverse relation tag -> posts, computed from the single source of truth
  // (post.tags) by filtering the full posts collection.
  const tagId = data.item.id || '';
  const posts = Object.values(data.posts ?? {})
    .filter((post) => (post.tags ?? []).includes(tagId))
    .sort((a, b) => (b.date || '').localeCompare(a.date || ''));

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.title && (
          <h2 className="font-display font-black text-[clamp(1.6rem,3.5vw,2.6rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}
          </h2>
        )}
        {posts.length > 0 ? (
          <div className="mt-10 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {posts.map((post, idx) => (
              <a key={post.id || `legacy-${idx}`} href={'/posts/' + (post.id || '')} className="group">
                <Card className="h-full overflow-hidden rounded-[var(--local-radius-lg)] border-[var(--local-border)] bg-[var(--local-surface)] py-0 transition group-hover:border-[var(--local-accent)]">
                  {post.image?.url && (
                    <div className="h-36 overflow-hidden">
                      <img
                        src={post.image.url}
                        alt={post.image.alt || ''}
                        className="h-full w-full object-cover transition duration-500 group-hover:scale-[1.03]"
                      />
                    </div>
                  )}
                  <CardContent className="p-6">
                    <div className="font-mono text-[0.68rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)]">
                      {post.date} · {post.readingTime}
                    </div>
                    <h3 className="mt-2 font-display text-[1.1rem] font-bold leading-tight tracking-tight text-[var(--local-text)]">
                      {post.title}
                    </h3>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--local-text-muted)]">{post.excerpt}</p>
                  </CardContent>
                </Card>
              </a>
            ))}
          </div>
        ) : (
          data.emptyLabel && (
            <p className="mt-10 text-sm text-[var(--local-text-muted)]" data-jp-field="emptyLabel">
              {data.emptyLabel}
            </p>
          )
        )}
      </div>
    </section>
  );
};
EOF

cat > src/components/tag-posts/index.ts << 'EOF'
export { TagPosts } from './View';
export { TagPostsSchema } from './schema';
export type { TagPostsData, TagPostsSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: content-block
# -----------------------------------------------------------------------------
echo "-- Writing capsule: content-block..."
cat > src/components/content-block/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem, ImageSelectionSchema } from '@olonjs/core';

const ParagraphSchema = BaseArrayItem.extend({
  text: z.string().describe('ui:textarea'),
});

export const ContentBlockSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  paragraphs: z.array(ParagraphSchema).describe('ui:list'),
  image: ImageSelectionSchema.optional(),
});
EOF

cat > src/components/content-block/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ContentBlockSchema } from './schema';

export type ContentBlockData = z.infer<typeof ContentBlockSchema>;
export type ContentBlockSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/content-block/View.tsx << 'EOF'
import React from 'react';
import { AspectRatio } from '@/components/ui/aspect-ratio';
import type { ContentBlockData, ContentBlockSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const ContentBlock: React.FC<{ data: ContentBlockData; settings: ContentBlockSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        <div className={data.image?.url ? 'grid items-start gap-12 md:grid-cols-2' : ''}>
          <div>
            {data.label && (
              <div
                className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
                data-jp-field="label"
              >
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.2rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
            <div className="mt-8 space-y-5">
              {data.paragraphs.map((paragraph, idx) => (
                <p
                  key={paragraph.id || `legacy-${idx}`}
                  className="max-w-[62ch] text-base leading-[1.85] text-[var(--local-text-muted)]"
                  data-jp-item-id={paragraph.id || `legacy-${idx}`}
                  data-jp-item-field="paragraphs"
                >
                  {paragraph.text}
                </p>
              ))}
            </div>
          </div>
          {data.image?.url && (
            <div className="overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]">
              <AspectRatio ratio={4 / 5}>
                <img src={data.image.url} alt={data.image.alt || ''} className="h-full w-full object-cover" />
              </AspectRatio>
            </div>
          )}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/content-block/index.ts << 'EOF'
export { ContentBlock } from './View';
export { ContentBlockSchema } from './schema';
export type { ContentBlockData, ContentBlockSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: stats-band (uses ui:icon-picker -> triggers STEP 9)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: stats-band..."
cat > src/components/stats-band/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const StatSchema = BaseArrayItem.extend({
  icon: z.string().optional().describe('ui:icon-picker'),
  value: z.string().describe('ui:text'),
  label: z.string().describe('ui:text'),
});

export const StatsBandSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().optional().describe('ui:text'),
  stats: z.array(StatSchema).describe('ui:list'),
});
EOF

cat > src/components/stats-band/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { StatsBandSchema } from './schema';

export type StatsBandData = z.infer<typeof StatsBandSchema>;
export type StatsBandSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/stats-band/View.tsx << 'EOF'
import React from 'react';
import { iconMap } from '@/lib/IconResolver';
import type { StatsBandData, StatsBandSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const StatsBand: React.FC<{ data: StatsBandData; settings: StatsBandSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-accent-soft': 'var(--demo-accent-soft)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.label && (
          <div
            className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
            data-jp-field="label"
          >
            <span className="w-5 h-px bg-[var(--local-primary)]" />
            {data.label}
          </div>
        )}
        {data.title && (
          <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.2rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}
          </h2>
        )}
        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {data.stats.map((stat, idx) => {
            const Icon = stat.icon ? iconMap[stat.icon] : undefined;
            return (
              <div
                key={stat.id || `legacy-${idx}`}
                className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6"
                data-jp-item-id={stat.id || `legacy-${idx}`}
                data-jp-item-field="stats"
              >
                {Icon && (
                  <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-[var(--local-accent-soft)]">
                    <Icon className="h-5 w-5 text-[var(--local-primary)]" />
                  </span>
                )}
                <div className="mt-4 font-display text-[2.2rem] font-black leading-none tracking-tight text-[var(--local-text)]">
                  {stat.value}
                </div>
                <div className="mt-2 text-sm text-[var(--local-text-muted)]">{stat.label}</div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/stats-band/index.ts << 'EOF'
export { StatsBand } from './View';
export { StatsBandSchema } from './schema';
export type { StatsBandData, StatsBandSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: cta-banner
# -----------------------------------------------------------------------------
echo "-- Writing capsule: cta-banner..."
cat > src/components/cta-banner/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';

export const CtaBannerSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  primaryCta: CtaSchema,
  secondaryCta: CtaSchema.optional(),
});
EOF

cat > src/components/cta-banner/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { CtaBannerSchema } from './schema';

export type CtaBannerData = z.infer<typeof CtaBannerSchema>;
export type CtaBannerSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/cta-banner/View.tsx << 'EOF'
import React from 'react';
import { Button } from '@/components/ui/button';
import type { CtaBannerData, CtaBannerSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const CtaBanner: React.FC<{ data: CtaBannerData; settings: CtaBannerSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-accent': 'var(--accent)',
        '--local-accent-soft': 'var(--demo-accent-soft)',
        '--local-border': t.border,
        '--local-radius-md': 'var(--theme-radius-md)',
      } as React.CSSProperties}
      className={`relative z-0 overflow-hidden ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[1100px] h-[650px] bg-[radial-gradient(ellipse_at_50%_0%,var(--local-accent-soft),transparent_65%)] pointer-events-none" />
      <div className={containerClass}>
        <div className="mx-auto max-w-[840px] text-center">
          {data.label && (
            <div
              className="inline-flex items-center gap-2 bg-[var(--local-accent-soft)] border border-[var(--local-border)] px-4 py-1.5 rounded-full text-[0.70rem] font-mono font-semibold text-[var(--local-accent)] tracking-widest uppercase"
              data-jp-field="label"
            >
              <span className="w-1.5 h-1.5 rounded-full bg-[var(--local-primary)] jp-pulse-dot" />
              {data.label}
            </div>
          )}
          <h2
            className="mt-8 font-display font-black text-[clamp(3rem,7vw,6.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]"
            data-jp-field="title"
          >
            {data.title}
          </h2>
          {data.description && (
            <p className="mx-auto mt-6 max-w-[52ch] text-lg leading-relaxed text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
          )}
          <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
            <Button
              asChild
              variant="default"
              size="lg"
              className="rounded-[var(--local-radius-md)] bg-[var(--local-primary)] text-[var(--local-primary-foreground)] hover:opacity-90"
            >
              <a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a>
            </Button>
            {data.secondaryCta && (
              <Button
                asChild
                variant="outline"
                size="lg"
                className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-transparent text-[var(--local-text)] hover:border-[var(--local-accent)]"
              >
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

cat > src/components/cta-banner/index.ts << 'EOF'
export { CtaBanner } from './View';
export { CtaBannerSchema } from './schema';
export type { CtaBannerData, CtaBannerSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# STEP 2 — src/types.ts (module augmentation — THE BRAIN)
# -----------------------------------------------------------------------------
echo "-- Writing src/types.ts..."
cat > src/types.ts << 'EOF'
import type { HeaderData, HeaderSettings } from '@/components/header';
import type { FooterData, FooterSettings } from '@/components/footer';
import type { HeroData, HeroSettings } from '@/components/hero';
import type { PageHeroData, PageHeroSettings } from '@/components/page-hero';
import type { PostsListData, PostsListSettings } from '@/components/posts-list';
import type { TagsListData, TagsListSettings } from '@/components/tags-list';
import type { PostDetailData, PostDetailSettings } from '@/components/post-detail';
import type { RelatedTagsData, RelatedTagsSettings } from '@/components/related-tags';
import type { TagDetailData, TagDetailSettings } from '@/components/tag-detail';
import type { TagPostsData, TagPostsSettings } from '@/components/tag-posts';
import type { ContentBlockData, ContentBlockSettings } from '@/components/content-block';
import type { StatsBandData, StatsBandSettings } from '@/components/stats-band';
import type { CtaBannerData, CtaBannerSettings } from '@/components/cta-banner';

export type SectionComponentPropsMap = {
  'header': { data: HeaderData; settings: HeaderSettings };
  'footer': { data: FooterData; settings: FooterSettings };
  'hero': { data: HeroData; settings: HeroSettings };
  'page-hero': { data: PageHeroData; settings: PageHeroSettings };
  'posts-list': { data: PostsListData; settings: PostsListSettings };
  'tags-list': { data: TagsListData; settings: TagsListSettings };
  'post-detail': { data: PostDetailData; settings: PostDetailSettings };
  'related-tags': { data: RelatedTagsData; settings: RelatedTagsSettings };
  'tag-detail': { data: TagDetailData; settings: TagDetailSettings };
  'tag-posts': { data: TagPostsData; settings: TagPostsSettings };
  'content-block': { data: ContentBlockData; settings: ContentBlockSettings };
  'stats-band': { data: StatsBandData; settings: StatsBandSettings };
  'cta-banner': { data: CtaBannerData; settings: CtaBannerSettings };
};

declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    'header': HeaderData;
    'footer': FooterData;
    'hero': HeroData;
    'page-hero': PageHeroData;
    'posts-list': PostsListData;
    'tags-list': TagsListData;
    'post-detail': PostDetailData;
    'related-tags': RelatedTagsData;
    'tag-detail': TagDetailData;
    'tag-posts': TagPostsData;
    'content-block': ContentBlockData;
    'stats-band': StatsBandData;
    'cta-banner': CtaBannerData;
  }
  export interface SectionSettingsRegistry {
    'header': HeaderSettings;
    'footer': FooterSettings;
    'hero': HeroSettings;
    'page-hero': PageHeroSettings;
    'posts-list': PostsListSettings;
    'tags-list': TagsListSettings;
    'post-detail': PostDetailSettings;
    'related-tags': RelatedTagsSettings;
    'tag-detail': TagDetailSettings;
    'tag-posts': TagPostsSettings;
    'content-block': ContentBlockSettings;
    'stats-band': StatsBandSettings;
    'cta-banner': CtaBannerSettings;
  }
}

export * from '@olonjs/core';
EOF

# -----------------------------------------------------------------------------
# STEP 3 — src/lib/ComponentRegistry.tsx (THE MAP — 13 imports, 13 keys)
# -----------------------------------------------------------------------------
echo "-- Writing src/lib/ComponentRegistry.tsx..."
cat > src/lib/ComponentRegistry.tsx << 'EOF'
import React from 'react';
import { Header } from '@/components/header';
import { Footer } from '@/components/footer';
import { Hero } from '@/components/hero';
import { PageHero } from '@/components/page-hero';
import { PostsList } from '@/components/posts-list';
import { TagsList } from '@/components/tags-list';
import { PostDetail } from '@/components/post-detail';
import { RelatedTags } from '@/components/related-tags';
import { TagDetail } from '@/components/tag-detail';
import { TagPosts } from '@/components/tag-posts';
import { ContentBlock } from '@/components/content-block';
import { StatsBand } from '@/components/stats-band';
import { CtaBanner } from '@/components/cta-banner';

import type { SectionType } from '@olonjs/core';
import type { SectionComponentPropsMap } from '@/types';

export const ComponentRegistry: {
  [K in SectionType]: React.FC<SectionComponentPropsMap[K]>;
} = {
  'header': Header,
  'footer': Footer,
  'hero': Hero,
  'page-hero': PageHero,
  'posts-list': PostsList,
  'tags-list': TagsList,
  'post-detail': PostDetail,
  'related-tags': RelatedTags,
  'tag-detail': TagDetail,
  'tag-posts': TagPosts,
  'content-block': ContentBlock,
  'stats-band': StatsBand,
  'cta-banner': CtaBanner,
};
EOF

# -----------------------------------------------------------------------------
# STEP 4 — src/lib/schemas.ts (THE INSPECTOR)
# -----------------------------------------------------------------------------
echo "-- Writing src/lib/schemas.ts..."
cat > src/lib/schemas.ts << 'EOF'
import { HeaderSchema } from '@/components/header';
import { FooterSchema } from '@/components/footer';
import { HeroSchema } from '@/components/hero';
import { PageHeroSchema } from '@/components/page-hero';
import { PostsListSchema } from '@/components/posts-list';
import { TagsListSchema } from '@/components/tags-list';
import { PostDetailSchema } from '@/components/post-detail';
import { RelatedTagsSchema } from '@/components/related-tags';
import { TagDetailSchema } from '@/components/tag-detail';
import { TagPostsSchema } from '@/components/tag-posts';
import { ContentBlockSchema } from '@/components/content-block';
import { StatsBandSchema } from '@/components/stats-band';
import { CtaBannerSchema } from '@/components/cta-banner';

export const SECTION_SCHEMAS = {
  'header': HeaderSchema,
  'footer': FooterSchema,
  'hero': HeroSchema,
  'page-hero': PageHeroSchema,
  'posts-list': PostsListSchema,
  'tags-list': TagsListSchema,
  'post-detail': PostDetailSchema,
  'related-tags': RelatedTagsSchema,
  'tag-detail': TagDetailSchema,
  'tag-posts': TagPostsSchema,
  'content-block': ContentBlockSchema,
  'stats-band': StatsBandSchema,
  'cta-banner': CtaBannerSchema,
} as const;

// Submission schemas per section type. Required runtime export — keep
// even if empty: omitting it makes the engine bootstrap fail at startup.
export const SECTION_SUBMISSION_SCHEMAS = {
  // no form capsules in this tenant
} as const;

export type SectionType = keyof typeof SECTION_SCHEMAS;

export {
  BaseSectionData,
  BaseArrayItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema,
} from '@olonjs/core';
EOF

# -----------------------------------------------------------------------------
# STEP 5 — src/lib/addSectionConfig.ts (THE LIBRARY)
# -----------------------------------------------------------------------------
echo "-- Writing src/lib/addSectionConfig.ts..."
cat > src/lib/addSectionConfig.ts << 'EOF'
import type { AddSectionConfig } from '@olonjs/core';

// Detail capsules (post-detail, related-tags, tag-detail, tag-posts) are
// intentionally NOT addable: they depend on the `collection:current` binding,
// which only exists on pages declaring a `collection` route (COP §8).
const addableSectionTypes = [
  'hero',
  'page-hero',
  'posts-list',
  'tags-list',
  'content-block',
  'stats-band',
  'cta-banner',
] as const;

const sectionTypeLabels: Record<string, string> = {
  'hero': 'Editorial Hero',
  'page-hero': 'Page Hero',
  'posts-list': 'Posts List',
  'tags-list': 'Tags List',
  'content-block': 'Content Block',
  'stats-band': 'Stats Band',
  'cta-banner': 'CTA Banner',
};

function getDefaultSectionData(type: string): Record<string, unknown> {
  switch (type) {
    case 'hero':
      return {
        title: 'A headline worth reading',
        subtitle: 'Say the one thing this page exists to say.',
        primaryCta: { id: 'cta-primary', label: 'Read the journal', href: '/posts', variant: 'primary' },
      };
    case 'page-hero':
      return { title: 'New page title' };
    case 'posts-list':
      return { title: 'Latest posts', items: {} };
    case 'tags-list':
      return { title: 'Browse by topic', items: {} };
    case 'content-block':
      return { title: 'A section worth writing', paragraphs: [] };
    case 'stats-band':
      return { stats: [] };
    case 'cta-banner':
      return {
        title: 'Start reading',
        primaryCta: { id: 'cta-primary', label: 'Browse the posts', href: '/posts', variant: 'primary' },
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
EOF

# -----------------------------------------------------------------------------
# STEP 9 — src/lib/IconResolver.tsx (ui:icon-picker used by stats-band)
# -----------------------------------------------------------------------------
echo "-- Writing src/lib/IconResolver.tsx..."
cat > src/lib/IconResolver.tsx << 'EOF'
import type { LucideIcon } from 'lucide-react';
import { PenLine, Tag, Users, Sparkles, BookOpen, Rss } from 'lucide-react';

export const iconMap: Record<string, LucideIcon> = {
  'pen-line': PenLine,
  'tag': Tag,
  'users': Users,
  'sparkles': Sparkles,
  'book-open': BookOpen,
  'rss': Rss,
};
EOF

# -----------------------------------------------------------------------------
# STEP 7 — CONFIG DATA
# -----------------------------------------------------------------------------
echo "-- Writing src/data/config/theme.json..."
cat > src/data/config/theme.json << 'EOF'
{
  "name": "Inkwell Journal",
  "tokens": {
    "colors": {
      "background": "#101014",
      "foreground": "#ece9e2",
      "card": "#17171d",
      "card-foreground": "#ece9e2",
      "elevated": "#1d1d25",
      "overlay": "#22222b",
      "primary": "#e0745c",
      "primary-foreground": "#14100e",
      "primary-light": "#eb9480",
      "primary-dark": "#b85a45",
      "accent": "#9db4e8",
      "accent-foreground": "#10131c",
      "secondary": "#23232c",
      "secondary-foreground": "#d8d5cd",
      "muted": "#1b1b22",
      "muted-foreground": "#97948c",
      "border": "#26262f",
      "border-strong": "#34343f",
      "input": "#1d1d25",
      "ring": "#e0745c",
      "destructive": "#e5484d",
      "destructive-foreground": "#fff0f0",
      "success": "#4cc38a",
      "success-foreground": "#06130c",
      "warning": "#f5b944",
      "warning-foreground": "#171105",
      "info": "#6ba6f5",
      "info-foreground": "#081321"
    },
    "typography": {
      "fontFamily": {
        "primary": "'Instrument Sans', system-ui, sans-serif",
        "mono": "'JetBrains Mono', monospace",
        "display": "'Bricolage Grotesque', system-ui, sans-serif"
      },
      "wordmark": {
        "fontFamily": "'Bricolage Grotesque', system-ui, sans-serif",
        "weight": "800"
      }
    },
    "borderRadius": { "sm": "4px", "md": "8px", "lg": "14px", "xl": "20px", "full": "9999px" },
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
          "background": "#faf8f4",
          "foreground": "#1d1c1a",
          "card": "#ffffff",
          "card-foreground": "#1d1c1a",
          "elevated": "#f2efe8",
          "overlay": "#e8e4da",
          "primary": "#c1543c",
          "primary-foreground": "#fdf6f3",
          "primary-light": "#d4765f",
          "primary-dark": "#9c4230",
          "accent": "#4a66b0",
          "accent-foreground": "#f5f7fd",
          "secondary": "#ece8df",
          "secondary-foreground": "#37352f",
          "muted": "#f0ede5",
          "muted-foreground": "#6d6a61",
          "border": "#e0dcd1",
          "border-strong": "#c9c4b6",
          "input": "#ffffff",
          "ring": "#c1543c",
          "destructive": "#d33c41",
          "destructive-foreground": "#fff5f5",
          "success": "#1f7a4d",
          "success-foreground": "#f0fbf5",
          "warning": "#a86a0b",
          "warning-foreground": "#fffaf0",
          "info": "#2563c4",
          "info-foreground": "#f0f6ff"
        }
      }
    }
  }
}
EOF

echo "-- Writing src/data/config/site.json..."
cat > src/data/config/site.json << 'EOF'
{
  "header": {
    "id": "global-header",
    "type": "header",
    "data": {
      "logoText": "Inkwell",
      "logoHighlight": "journal",
      "announcement": "Collections demo: posts and tags, linked both ways",
      "menu": { "$ref": "../config/menu.json#/main" }
    },
    "settings": { "sticky": true }
  },
  "footer": {
    "id": "global-footer",
    "type": "footer",
    "data": {
      "brandText": "Inkwell",
      "tagline": "Notes on the craft of making software. An OlonJS demo tenant showing collections and cross-collection relations.",
      "email": "hello@inkwell-journal.example",
      "copyright": "© 2026 Inkwell Journal. Written slowly, shipped quietly.",
      "menu": { "$ref": "../config/menu.json#/footer" }
    },
    "settings": { "showLogo": true }
  },
  "identity": { "title": "Inkwell Journal" }
}
EOF

echo "-- Writing src/data/config/menu.json..."
cat > src/data/config/menu.json << 'EOF'
{
  "main": [
    { "id": "menu-home", "label": "Home", "href": "/" },
    { "id": "menu-posts", "label": "Posts", "href": "/posts" },
    { "id": "menu-tags", "label": "Topics", "href": "/tags" },
    { "id": "menu-about", "label": "About", "href": "/about" },
    { "id": "menu-contact", "label": "Contact", "href": "/contact", "isCta": true }
  ],
  "footer": [
    { "id": "footer-posts", "label": "Posts", "href": "/posts" },
    { "id": "footer-tags", "label": "Topics", "href": "/tags" },
    { "id": "footer-about", "label": "About", "href": "/about" },
    { "id": "footer-contact", "label": "Contact", "href": "/contact" }
  ]
}
EOF

# -----------------------------------------------------------------------------
# STEP 7 — PAGES
# -----------------------------------------------------------------------------
echo "-- Writing page: home..."
cat > src/data/pages/home.json << 'EOF'
{
  "id": "home-page",
  "slug": "home",
  "meta": {
    "title": "Inkwell Journal — Notes on the craft of software",
    "description": "An editorial journal about design, engineering and process, built on OlonJS collections: every post and every tag is a first-class entity with its own page."
  },
  "sections": [
    {
      "id": "home-hero",
      "type": "hero",
      "data": {
        "label": "An OlonJS collections demo",
        "title": "Notes on the",
        "titleHighlight": "craft of software",
        "subtitle": "Essays on design, engineering and process — published as a living demo of cross-collection relations: every post belongs to many tags, and every tag knows its posts without storing them twice.",
        "primaryCta": { "id": "home-hero-cta-1", "label": "Read the posts", "href": "/posts", "variant": "primary" },
        "secondaryCta": { "id": "home-hero-cta-2", "label": "Browse topics", "href": "/tags", "variant": "secondary" },
        "image": { "url": "https://images.unsplash.com/photo-1456735190827-d1262f71b8a3?w=2000&q=80", "alt": "Fountain pen nib in sharp close-up over paper" }
      },
      "settings": { "paddingTop": "xl", "paddingBottom": "none" }
    },
    {
      "id": "home-featured-posts",
      "type": "posts-list",
      "data": {
        "label": "Fresh ink",
        "title": "Latest from the desk",
        "description": "The four most recent essays, pulled live from the posts collection and sorted by date.",
        "variant": "bento",
        "limit": 4,
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "home-tags",
      "type": "tags-list",
      "data": {
        "label": "Topics",
        "title": "Browse by topic",
        "description": "Six tags, one collection. Each card links to a tag page that computes its own post list from the relation.",
        "items": { "$ref": "../collections/tags/tags.json" }
      },
      "settings": {}
    },
    {
      "id": "home-stats",
      "type": "stats-band",
      "data": {
        "label": "The journal in numbers",
        "title": "Small, deliberate, linked",
        "stats": [
          { "id": "stat-posts", "icon": "pen-line", "value": "8", "label": "Essays published, each in a posts collection entry" },
          { "id": "stat-tags", "icon": "tag", "value": "6", "label": "Topics in the tags collection" },
          { "id": "stat-relations", "icon": "sparkles", "value": "14", "label": "Post-to-tag links resolved at render time" },
          { "id": "stat-authors", "icon": "users", "value": "4", "label": "Writers behind the desk" }
        ]
      },
      "settings": {}
    },
    {
      "id": "home-cta",
      "type": "cta-banner",
      "data": {
        "label": "Start anywhere",
        "title": "Pick a thread, pull it",
        "description": "Every post links to its topics and every topic links back to its posts. That is the whole demo — and the whole point.",
        "primaryCta": { "id": "home-cta-1", "label": "Read the latest", "href": "/posts", "variant": "primary" },
        "secondaryCta": { "id": "home-cta-2", "label": "About this demo", "href": "/about", "variant": "secondary" }
      },
      "settings": { "paddingTop": "xl", "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: posts..."
cat > src/data/pages/posts.json << 'EOF'
{
  "id": "posts-page",
  "slug": "posts",
  "meta": {
    "title": "All posts — Inkwell Journal essay archive",
    "description": "The complete archive of Inkwell Journal essays on design, engineering, writing and process, rendered as a timeline from the posts collection."
  },
  "sections": [
    {
      "id": "posts-hero",
      "type": "page-hero",
      "data": {
        "label": "Archive",
        "title": "Every post, in order",
        "description": "The full posts collection rendered as a timeline. Each entry carries its tag keys — follow one to jump into the inverse relation."
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "posts-archive",
      "type": "posts-list",
      "data": {
        "title": "The archive",
        "variant": "timeline",
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": {}
    },
    {
      "id": "posts-topics",
      "type": "tags-list",
      "data": {
        "label": "Another way in",
        "title": "Prefer to browse by topic?",
        "items": { "$ref": "../collections/tags/tags.json" }
      },
      "settings": {}
    },
    {
      "id": "posts-cta",
      "type": "cta-banner",
      "data": {
        "title": "Say hello",
        "description": "Questions about the writing, or about how this demo wires its collections together? We read every message.",
        "primaryCta": { "id": "posts-cta-1", "label": "Contact us", "href": "/contact", "variant": "primary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: tags..."
cat > src/data/pages/tags.json << 'EOF'
{
  "id": "tags-page",
  "slug": "tags",
  "meta": {
    "title": "Topics — browse Inkwell Journal by tag",
    "description": "Six topics spanning design, engineering, process, writing, tooling and culture. Each tag page computes its own post list from the posts-to-tags relation."
  },
  "sections": [
    {
      "id": "tags-hero",
      "type": "page-hero",
      "data": {
        "label": "Topics",
        "title": "Browse by topic",
        "description": "Tags are their own collection. No tag stores a post list — each tag page filters the posts collection live, so the relation can never drift out of sync."
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "tags-all",
      "type": "tags-list",
      "data": {
        "title": "All topics",
        "items": { "$ref": "../collections/tags/tags.json" }
      },
      "settings": {}
    },
    {
      "id": "tags-recent-posts",
      "type": "posts-list",
      "data": {
        "label": "Or start reading",
        "title": "Fresh off the press",
        "variant": "bento",
        "limit": 3,
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": {}
    },
    {
      "id": "tags-cta",
      "type": "cta-banner",
      "data": {
        "title": "Lost? Start at the top",
        "primaryCta": { "id": "tags-cta-1", "label": "Back to home", "href": "/", "variant": "primary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: posts/[slug] (post detail + related-tags)..."
cat > src/data/pages/post-detail.json << 'EOF'
{
  "id": "post-detail-page",
  "slug": "posts/[slug]",
  "collection": { "source": "posts", "paramKey": "slug" },
  "meta": {
    "title": "Post — Inkwell Journal essay detail",
    "description": "A single essay from the Inkwell Journal posts collection, with its related topics resolved live from the posts-to-tags relation."
  },
  "sections": [
    {
      "id": "post-detail-body",
      "type": "post-detail",
      "data": {
        "backLabel": "All posts",
        "item": { "$ref": "collection:current" }
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "post-detail-related-tags",
      "type": "related-tags",
      "data": {
        "label": "Relations demo",
        "title": "Filed under",
        "emptyLabel": "This post has no topics yet.",
        "item": { "$ref": "collection:current" },
        "tags": { "$ref": "../collections/tags/tags.json" }
      },
      "settings": {}
    },
    {
      "id": "post-detail-cta",
      "type": "cta-banner",
      "data": {
        "title": "Keep reading",
        "primaryCta": { "id": "post-detail-cta-1", "label": "Back to the archive", "href": "/posts", "variant": "primary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: tags/[slug] (tag detail + tag-posts)..."
cat > src/data/pages/tag-detail.json << 'EOF'
{
  "id": "tag-detail-page",
  "slug": "tags/[slug]",
  "collection": { "source": "tags", "paramKey": "slug" },
  "meta": {
    "title": "Topic — Inkwell Journal posts by tag",
    "description": "A single topic from the tags collection, with every matching essay computed live by filtering the posts collection on the current tag key."
  },
  "sections": [
    {
      "id": "tag-detail-head",
      "type": "tag-detail",
      "data": {
        "backLabel": "All topics",
        "item": { "$ref": "collection:current" }
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "tag-detail-posts",
      "type": "tag-posts",
      "data": {
        "title": "Posts on this topic",
        "emptyLabel": "No posts carry this tag yet.",
        "item": { "$ref": "collection:current" },
        "posts": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": {}
    },
    {
      "id": "tag-detail-cta",
      "type": "cta-banner",
      "data": {
        "title": "Explore another thread",
        "primaryCta": { "id": "tag-detail-cta-1", "label": "All topics", "href": "/tags", "variant": "primary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: about..."
cat > src/data/pages/about.json << 'EOF'
{
  "id": "about-page",
  "slug": "about",
  "meta": {
    "title": "About Inkwell Journal and this collections demo",
    "description": "Inkwell Journal is a working OlonJS demo: posts and tags live as separate collections, related through keys on the post side and resolved at render time."
  },
  "sections": [
    {
      "id": "about-hero",
      "type": "page-hero",
      "data": {
        "label": "About",
        "title": "A journal that is also a diagram",
        "description": "Inkwell exists to show one architectural idea clearly: entities as collections, relations as keys, and rendering as resolution."
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "about-story",
      "type": "content-block",
      "data": {
        "label": "How it works",
        "title": "One source of truth per relation",
        "paragraphs": [
          { "id": "about-p1", "text": "Every essay in this journal is an entry in the posts collection, and every topic is an entry in the tags collection. A post declares its topics as an array of tag keys — that array is the only place the relation is stored." },
          { "id": "about-p2", "text": "The post page resolves those keys against the tags collection to render its topic chips. The tag page runs the relation in reverse: it filters the whole posts collection for entries carrying its key. Nothing is denormalized, so nothing can drift." },
          { "id": "about-p3", "text": "Everything you see — copy, images, colors, even this paragraph — is schema-driven data, editable in the OlonJS Studio without touching a line of component code." }
        ],
        "image": { "url": "https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=1600&q=80", "alt": "Tall library shelves filled with books seen from below" }
      },
      "settings": {}
    },
    {
      "id": "about-stats",
      "type": "stats-band",
      "data": {
        "label": "Under the hood",
        "title": "What powers the demo",
        "stats": [
          { "id": "about-stat-1", "icon": "book-open", "value": "2", "label": "Collections: posts and tags" },
          { "id": "about-stat-2", "icon": "tag", "value": "1", "label": "Direction of stored truth: post to tags" },
          { "id": "about-stat-3", "icon": "sparkles", "value": "2", "label": "Directions rendered: posts to tags, tags to posts" },
          { "id": "about-stat-4", "icon": "rss", "value": "7", "label": "Pages, two of them dynamic collection routes" }
        ]
      },
      "settings": {}
    },
    {
      "id": "about-cta",
      "type": "cta-banner",
      "data": {
        "title": "See it in motion",
        "description": "Open any post, tap a topic chip, and watch the inverse relation resolve on the tag page.",
        "primaryCta": { "id": "about-cta-1", "label": "Open the archive", "href": "/posts", "variant": "primary" },
        "secondaryCta": { "id": "about-cta-2", "label": "Browse topics", "href": "/tags", "variant": "secondary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: contact..."
cat > src/data/pages/contact.json << 'EOF'
{
  "id": "contact-page",
  "slug": "contact",
  "meta": {
    "title": "Contact the Inkwell Journal editorial desk",
    "description": "Write to the Inkwell Journal desk about the essays, the OlonJS collections demo, or anything in between. We answer within two working days."
  },
  "sections": [
    {
      "id": "contact-hero",
      "type": "page-hero",
      "data": {
        "label": "Contact",
        "title": "Write to the desk",
        "description": "Questions, corrections, or curiosity about how the collections are wired — all welcome."
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "contact-details",
      "type": "content-block",
      "data": {
        "label": "Reach us",
        "title": "Where to find us",
        "paragraphs": [
          { "id": "contact-p1", "text": "Email is the fastest route: hello@inkwell-journal.example. We read everything and answer within two working days, usually sooner." },
          { "id": "contact-p2", "text": "The desk sits at Via dei Tipografi 12, 40126 Bologna — visits by appointment. If you are writing about a correction, include the post title and the paragraph you mean." }
        ],
        "image": { "url": "https://images.unsplash.com/photo-1504868584819-f8e8b4b6d7e3?w=1600&q=80", "alt": "Vintage typewriter with a blank sheet of paper on a desk" }
      },
      "settings": {}
    },
    {
      "id": "contact-editorial",
      "type": "content-block",
      "data": {
        "label": "Pitches",
        "title": "Want to write for Inkwell?",
        "paragraphs": [
          { "id": "contact-p3", "text": "We publish outside voices a few times a year. Pitch us one paragraph: the single sentence your piece exists to deliver, and why you are the person to write it." },
          { "id": "contact-p4", "text": "Every accepted piece becomes an entry in the posts collection with its own tags — your essay ships wired into the same relation graph you are reading now." }
        ]
      },
      "settings": {}
    },
    {
      "id": "contact-cta",
      "type": "cta-banner",
      "data": {
        "title": "Or just start reading",
        "primaryCta": { "id": "contact-cta-1", "label": "Latest posts", "href": "/posts", "variant": "primary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

# -----------------------------------------------------------------------------
# STEP 9 — AdminStudioClient wiring check (iconRegistry + collections + collectionSchemas)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# BUILD
# -----------------------------------------------------------------------------
echo "-- Building..."
npm run build

echo ""
echo "=============================================================="
echo "  INKWELL JOURNAL — spec-compliance checklist"
echo "=============================================================="
echo "  [x] Step 0  shadcn/ui init + component set (new-york, slate)"
echo "  [x] Step 1  13 capsules: header, footer, hero, page-hero,"
echo "              posts-list, tags-list, post-detail, related-tags,"
echo "              tag-detail, tag-posts, content-block, stats-band,"
echo "              cta-banner (View/schema/types/index each)"
echo "  [x] Step 2  src/types.ts — 13 entries in PropsMap + both registries"
echo "  [x] Step 3  ComponentRegistry — 13 imports == 13 keys"
echo "  [x] Step 4  SECTION_SCHEMAS (13) + SECTION_SUBMISSION_SCHEMAS (empty)"
echo "  [x] Step 5  addSectionConfig — 7 addable types (detail capsules excluded)"
echo "  [x] Step 6  globals.css — fonts @import first line, semantic bridge,"
echo "              [data-theme=light] override, TOCC overlay, animations"
echo "  [x] Step 7  theme.json (dark + modes.light), site.json ($ref menu),"
echo "              menu.json, 7 pages (all ids end in -page)"
echo "  [x] Step 8  COP: posts + tags collections (keyed objects),"
echo "              CollectionRegistry, ui:collection-ref bindings,"
echo "              posts/[slug] + tags/[slug] dynamic pages,"
echo "              collection:current refs on detail sections"
echo "  [x] Step 9  IconResolver (6 icons) + AdminStudioClient wiring verified"
echo "  [x] Relations: posts->tags stored on post side only;"
echo "              tags->posts computed at render (tag-posts capsule);"
echo "              post detail resolves tag keys (related-tags capsule)"
echo "  [x] Light/dark: both palettes designed; header toggle via dataset.theme"
echo "  [x] Typography: Bricolage Grotesque / Instrument Sans / JetBrains Mono"
echo "  [x] No emoji, no hardcoded theme colors, CTAs use .label,"
echo "              images use optional chaining, z-0 on section roots"
echo "=============================================================="
