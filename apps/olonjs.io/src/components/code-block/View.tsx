"use client";

/* OlonJS capsule: Shiki block + compound API + CodeBlockView — single file per tenant convention. */

import { useControllableState } from "@radix-ui/react-use-controllable-state";
import { CheckIcon, CopyIcon } from "lucide-react";
import type { ComponentProps, CSSProperties, HTMLAttributes, ReactElement, ReactNode } from "react";
import { cloneElement, createContext, useContext, useEffect, useMemo, useState } from "react";
import type { IconType } from "react-icons";
import {
  SiAstro,
  SiBiome,
  SiBower,
  SiBun,
  SiC,
  SiCircleci,
  SiCoffeescript,
  SiCplusplus,
  SiCss,
  SiCssmodules,
  SiDart,
  SiDocker,
  SiDocusaurus,
  SiDotenv,
  SiEditorconfig,
  SiEslint,
  SiGatsby,
  SiGitignoredotio,
  SiGnubash,
  SiGo,
  SiGraphql,
  SiGrunt,
  SiGulp,
  SiHandlebarsdotjs,
  SiHtml5,
  SiJavascript,
  SiJest,
  SiJson,
  SiLess,
  SiMarkdown,
  SiMdx,
  SiMintlify,
  SiMocha,
  SiMysql,
  SiNextdotjs,
  SiPerl,
  SiPhp,
  SiPostcss,
  SiPrettier,
  SiPrisma,
  SiPug,
  SiPython,
  SiR,
  SiReact,
  SiReadme,
  SiRedis,
  SiRemix,
  SiRive,
  SiRollupdotjs,
  SiRuby,
  SiSanity,
  SiSass,
  SiScala,
  SiSentry,
  SiShadcnui,
  SiStorybook,
  SiStylelint,
  SiSublimetext,
  SiSvelte,
  SiSvg,
  SiSwift,
  SiTailwindcss,
  SiToml,
  SiTypescript,
  SiVercel,
  SiVite,
  SiVuedotjs,
  SiWebassembly,
} from "react-icons/si";
import type { BundledLanguage, CodeOptionsMultipleThemes } from "shiki";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { cn } from "@/lib/utils";
import type { CodeBlockData, CodeBlockSettings } from "./types";

export type { BundledLanguage } from "shiki";

const filenameIconMap = {
  ".env": SiDotenv,
  "*.astro": SiAstro,
  "biome.json": SiBiome,
  ".bowerrc": SiBower,
  "bun.lockb": SiBun,
  "*.c": SiC,
  "*.cpp": SiCplusplus,
  ".circleci/config.yml": SiCircleci,
  "*.coffee": SiCoffeescript,
  "*.module.css": SiCssmodules,
  "*.css": SiCss,
  "*.dart": SiDart,
  Dockerfile: SiDocker,
  "docusaurus.config.js": SiDocusaurus,
  ".editorconfig": SiEditorconfig,
  ".eslintrc": SiEslint,
  "eslint.config.*": SiEslint,
  "gatsby-config.*": SiGatsby,
  ".gitignore": SiGitignoredotio,
  "*.go": SiGo,
  "*.graphql": SiGraphql,
  "*.sh": SiGnubash,
  "Gruntfile.*": SiGrunt,
  "gulpfile.*": SiGulp,
  "*.hbs": SiHandlebarsdotjs,
  "*.html": SiHtml5,
  "*.js": SiJavascript,
  "*.json": SiJson,
  "*.test.js": SiJest,
  "*.less": SiLess,
  "*.md": SiMarkdown,
  "*.mdx": SiMdx,
  "mintlify.json": SiMintlify,
  "mocha.opts": SiMocha,
  "*.mustache": SiHandlebarsdotjs,
  "*.sql": SiMysql,
  "next.config.*": SiNextdotjs,
  "*.pl": SiPerl,
  "*.php": SiPhp,
  "postcss.config.*": SiPostcss,
  "prettier.config.*": SiPrettier,
  "*.prisma": SiPrisma,
  "*.pug": SiPug,
  "*.py": SiPython,
  "*.r": SiR,
  "*.rb": SiRuby,
  "*.jsx": SiReact,
  "*.tsx": SiReact,
  "readme.md": SiReadme,
  "*.rdb": SiRedis,
  "remix.config.*": SiRemix,
  "*.riv": SiRive,
  "rollup.config.*": SiRollupdotjs,
  "sanity.config.*": SiSanity,
  "*.sass": SiSass,
  "*.scss": SiSass,
  "*.sc": SiScala,
  "*.scala": SiScala,
  "sentry.client.config.*": SiSentry,
  "components.json": SiShadcnui,
  "storybook.config.*": SiStorybook,
  "stylelint.config.*": SiStylelint,
  ".sublime-settings": SiSublimetext,
  "*.svelte": SiSvelte,
  "*.svg": SiSvg,
  "*.swift": SiSwift,
  "tailwind.config.*": SiTailwindcss,
  "*.toml": SiToml,
  "*.ts": SiTypescript,
  "vercel.json": SiVercel,
  "vite.config.*": SiVite,
  "*.vue": SiVuedotjs,
  "*.wasm": SiWebassembly,
} as const;

const lineNumberClassNames = cn(
  "[&_code]:[counter-reset:line]",
  "[&_code]:[counter-increment:line_0]",
  "[&_.line]:before:content-[counter(line)]",
  "[&_.line]:before:inline-block",
  "[&_.line]:before:[counter-increment:line]",
  "[&_.line]:before:w-3",
  "[&_.line]:before:mr-3",
  "[&_.line]:before:text-[11px]",
  "sm:[&_.line]:before:w-4",
  "sm:[&_.line]:before:mr-4",
  "sm:[&_.line]:before:text-[13px]",
  "[&_.line]:before:text-right",
  "[&_.line]:before:text-muted-foreground/50",
  "[&_.line]:before:font-mono",
  "[&_.line]:before:select-none",
);

const darkModeClassNames = cn(
  "dark:[&_.shiki]:!text-[var(--shiki-dark)]",
  "dark:[&_.shiki]:![font-style:var(--shiki-dark-font-style)]",
  "dark:[&_.shiki]:![font-weight:var(--shiki-dark-font-weight)]",
  "dark:[&_.shiki]:![text-decoration:var(--shiki-dark-text-decoration)]",
  "dark:[&_.shiki_span]:!text-[var(--shiki-dark)]",
  "dark:[&_.shiki_span]:![font-style:var(--shiki-dark-font-style)]",
  "dark:[&_.shiki_span]:![font-weight:var(--shiki-dark-font-weight)]",
  "dark:[&_.shiki_span]:![text-decoration:var(--shiki-dark-text-decoration)]",
);

const lineHighlightClassNames = cn(
  "[&_.line.highlighted]:bg-blue-50",
  "[&_.line.highlighted]:after:bg-blue-500",
  "[&_.line.highlighted]:after:absolute",
  "[&_.line.highlighted]:after:left-0",
  "[&_.line.highlighted]:after:top-0",
  "[&_.line.highlighted]:after:bottom-0",
  "[&_.line.highlighted]:after:w-0.5",
  "dark:[&_.line.highlighted]:!bg-blue-500/10",
);

const lineDiffClassNames = cn(
  "[&_.line.diff]:after:absolute",
  "[&_.line.diff]:after:left-0",
  "[&_.line.diff]:after:top-0",
  "[&_.line.diff]:after:bottom-0",
  "[&_.line.diff]:after:w-0.5",
  "[&_.line.diff.add]:bg-emerald-50",
  "[&_.line.diff.add]:after:bg-emerald-500",
  "[&_.line.diff.remove]:bg-rose-50",
  "[&_.line.diff.remove]:after:bg-rose-500",
  "dark:[&_.line.diff.add]:!bg-emerald-500/10",
  "dark:[&_.line.diff.remove]:!bg-rose-500/10",
);

const lineFocusedClassNames = cn(
  "[&_code:has(.focused)_.line]:blur-[2px]",
  "[&_code:has(.focused)_.line.focused]:blur-none",
);

const wordHighlightClassNames = cn(
  "[&_.highlighted-word]:bg-blue-50",
  "dark:[&_.highlighted-word]:!bg-blue-500/10",
);

const codeBlockClassName = cn(
  "mt-0 bg-background text-[13px] sm:text-sm",
  "[&_pre]:py-3 sm:[&_pre]:py-4",
  "[&_.shiki]:!bg-transparent",
  "[&_code]:w-full",
  "[&_code]:grid",
  "[&_code]:overflow-x-auto",
  "[&_code]:bg-transparent",
  "[&_.line]:px-3 sm:[&_.line]:px-4",
  "[&_.line]:w-full",
  "[&_.line]:relative",
);

// Shiki + transformers are loaded on demand to keep the highlighter
// (and its WASM/grammar payload) out of the initial bundle. See ADR-0007.
const highlight = async (
  html: string,
  language?: BundledLanguage,
  themes?: CodeOptionsMultipleThemes["themes"],
): Promise<string> => {
  const [{ codeToHtml }, transformers] = await Promise.all([
    import("shiki"),
    import("@shikijs/transformers"),
  ]);
  return codeToHtml(html, {
    lang: language ?? "typescript",
    themes: themes ?? {
      light: "github-light",
      dark: "github-dark-default",
    },
    transformers: [
      transformers.transformerNotationDiff({ matchAlgorithm: "v3" }),
      transformers.transformerNotationHighlight({ matchAlgorithm: "v3" }),
      transformers.transformerNotationWordHighlight({ matchAlgorithm: "v3" }),
      transformers.transformerNotationFocus({ matchAlgorithm: "v3" }),
      transformers.transformerNotationErrorLevel({ matchAlgorithm: "v3" }),
    ],
  });
};

export type CodeBlockTabData = {
  id: string;
  language: string;
  filename: string;
  code: string;
};

type CodeBlockContextType = {
  value: string | undefined;
  onValueChange: ((value: string) => void) | undefined;
  data: CodeBlockTabData[];
};

const CodeBlockContext = createContext<CodeBlockContextType>({
  value: undefined,
  onValueChange: undefined,
  data: [],
});

export type CodeBlockProps = HTMLAttributes<HTMLDivElement> & {
  defaultValue?: string;
  value?: string;
  onValueChange?: (value: string) => void;
  data: CodeBlockTabData[];
};

export const CodeBlock = ({
  value: controlledValue,
  onValueChange: controlledOnValueChange,
  defaultValue,
  className,
  data,
  ...props
}: CodeBlockProps) => {
  const [value, onValueChange] = useControllableState({
    defaultProp: defaultValue ?? data[0]?.id ?? "",
    prop: controlledValue,
    onChange: controlledOnValueChange,
  });

  return (
    <CodeBlockContext.Provider value={{ value, onValueChange, data }}>
      <div className={cn("size-full min-w-0 max-w-full overflow-hidden rounded-md border", className)} {...props} />
    </CodeBlockContext.Provider>
  );
};

export type CodeBlockHeaderProps = HTMLAttributes<HTMLDivElement>;

export const CodeBlockHeader = ({ className, ...props }: CodeBlockHeaderProps) => (
  <div className={cn("flex flex-row items-center border-b bg-secondary p-1", className)} {...props} />
);

export type CodeBlockFilesProps = Omit<HTMLAttributes<HTMLDivElement>, "children"> & {
  children: (item: CodeBlockTabData) => ReactNode;
};

export const CodeBlockFiles = ({ className, children, ...props }: CodeBlockFilesProps) => {
  const { data } = useContext(CodeBlockContext);

  return (
    <div className={cn("flex grow flex-row items-center gap-2", className)} {...props}>
      {data.map(children)}
    </div>
  );
};

export type CodeBlockFilenameProps = HTMLAttributes<HTMLDivElement> & {
  icon?: IconType;
  value?: string;
};

export const CodeBlockFilename = ({ className, icon, value, children, ...props }: CodeBlockFilenameProps) => {
  const { value: activeValue } = useContext(CodeBlockContext);
  const defaultIcon = Object.entries(filenameIconMap).find(([pattern]) => {
    const regex = new RegExp(`^${pattern.replace(/\\/g, "\\\\").replace(/\./g, "\\.").replace(/\*/g, ".*")}$`);
    return regex.test(children as string);
  })?.[1];
  const Icon = icon ?? defaultIcon;

  if (value !== activeValue) {
    return null;
  }

  return (
    <div
      className={cn("flex items-center gap-2 bg-secondary px-4 py-1.5 text-muted-foreground text-xs", className)}
      {...props}
    >
      {Icon && <Icon className="h-4 w-4 shrink-0" />}
      <span className="flex-1 truncate">{children}</span>
    </div>
  );
};

export type CodeBlockSelectProps = ComponentProps<typeof Select>;

export const CodeBlockSelect = (props: CodeBlockSelectProps) => {
  const { value, onValueChange } = useContext(CodeBlockContext);

  return <Select onValueChange={onValueChange} value={value} {...props} />;
};

export type CodeBlockSelectTriggerProps = ComponentProps<typeof SelectTrigger>;

export const CodeBlockSelectTrigger = ({ className, ...props }: CodeBlockSelectTriggerProps) => (
  <SelectTrigger className={cn("w-fit border-none text-muted-foreground text-xs shadow-none", className)} {...props} />
);

export type CodeBlockSelectValueProps = ComponentProps<typeof SelectValue>;

export const CodeBlockSelectValue = (props: CodeBlockSelectValueProps) => <SelectValue {...props} />;

export type CodeBlockSelectContentProps = Omit<ComponentProps<typeof SelectContent>, "children"> & {
  children: (item: CodeBlockTabData) => ReactNode;
};

export const CodeBlockSelectContent = ({ children, ...props }: CodeBlockSelectContentProps) => {
  const { data } = useContext(CodeBlockContext);

  return <SelectContent {...props}>{data.map(children)}</SelectContent>;
};

export type CodeBlockSelectItemProps = ComponentProps<typeof SelectItem>;

export const CodeBlockSelectItem = ({ className, ...props }: CodeBlockSelectItemProps) => (
  <SelectItem className={cn("text-sm", className)} {...props} />
);

export type CodeBlockCopyButtonProps = ComponentProps<typeof Button> & {
  onCopy?: () => void;
  onError?: (error: Error) => void;
  timeout?: number;
};

export const CodeBlockCopyButton = ({
  asChild,
  onCopy,
  onError,
  timeout = 2000,
  children,
  className,
  ...props
}: CodeBlockCopyButtonProps) => {
  const [isCopied, setIsCopied] = useState(false);
  const { data, value } = useContext(CodeBlockContext);
  const code = data.find((item) => item.id === value)?.code;

  const copyToClipboard = () => {
    if (typeof window === "undefined" || !navigator.clipboard.writeText || !code) {
      return;
    }

    navigator.clipboard.writeText(code).then(() => {
      setIsCopied(true);
      onCopy?.();

      setTimeout(() => setIsCopied(false), timeout);
    }, onError);
  };

  if (asChild) {
    return cloneElement(children as ReactElement, {
      // @ts-expect-error - we know this is a button
      onClick: copyToClipboard,
    });
  }

  const Icon = isCopied ? CheckIcon : CopyIcon;

  return (
    <Button className={cn("shrink-0", className)} onClick={copyToClipboard} size="icon" variant="ghost" {...props}>
      {children ?? <Icon className="text-muted-foreground" size={14} />}
    </Button>
  );
};

type CodeBlockFallbackProps = HTMLAttributes<HTMLDivElement>;

const CodeBlockFallback = ({ children, ...props }: CodeBlockFallbackProps) => (
  <div {...props}>
    <pre className="w-full overflow-x-auto">
      <code>
        {children
          ?.toString()
          .split("\n")
          .map((line, i) => (
            <span className="line" key={i}>
              {line}
            </span>
          ))}
      </code>
    </pre>
  </div>
);

export type CodeBlockBodyProps = Omit<HTMLAttributes<HTMLDivElement>, "children"> & {
  children: (item: CodeBlockTabData) => ReactNode;
};

export const CodeBlockBody = ({ children, ...props }: CodeBlockBodyProps) => {
  const { data } = useContext(CodeBlockContext);

  return <div {...props}>{data.map(children)}</div>;
};

export type CodeBlockItemProps = HTMLAttributes<HTMLDivElement> & {
  value: string;
  lineNumbers?: boolean;
};

export const CodeBlockItem = ({ children, lineNumbers = true, className, value, ...props }: CodeBlockItemProps) => {
  const { value: activeValue } = useContext(CodeBlockContext);

  if (value !== activeValue) {
    return null;
  }

  return (
    <div
      className={cn(
        codeBlockClassName,
        lineHighlightClassNames,
        lineDiffClassNames,
        lineFocusedClassNames,
        wordHighlightClassNames,
        darkModeClassNames,
        lineNumbers && lineNumberClassNames,
        className,
      )}
      {...props}
    >
      {children}
    </div>
  );
};

export type CodeBlockContentProps = HTMLAttributes<HTMLDivElement> & {
  themes?: CodeOptionsMultipleThemes["themes"];
  language?: BundledLanguage;
  syntaxHighlighting?: boolean;
  children: string;
};

export const CodeBlockContent = ({
  children,
  themes,
  language,
  syntaxHighlighting = true,
  ...props
}: CodeBlockContentProps) => {
  const [html, setHtml] = useState<string | null>(null);

  useEffect(() => {
    if (!syntaxHighlighting) {
      return;
    }

    highlight(children as string, language, themes)
      .then(setHtml)
      .catch(console.error);
  }, [children, themes, syntaxHighlighting, language]);

  if (!(syntaxHighlighting && html)) {
    return <CodeBlockFallback>{children}</CodeBlockFallback>;
  }

  return <div dangerouslySetInnerHTML={{ __html: html }} {...props} />;
};

type CodeBlockSectionViewProps = {
  data: CodeBlockData;
  settings?: CodeBlockSettings;
};

function TerminalColumn({
  column,
  lineNumbers,
  syntaxHighlighting,
}: {
  column: CodeBlockData["columns"][number];
  lineNumbers: boolean;
  syntaxHighlighting: boolean;
}) {
  const tabData: CodeBlockTabData[] = useMemo(
    () =>
      column.tabs.map((t) => ({
        id: t.id ?? t.filename,
        filename: t.filename,
        language: t.language,
        code: t.code,
      })),
    [column.tabs],
  );

  const defaultId = tabData[0]?.id ?? "";

  return (
    <CodeBlock
      defaultValue={defaultId}
      data={tabData}
      className="border-[var(--local-border)]"
      data-jp-item-field="columns"
      data-jp-item-id={column.id}
    >
      <CodeBlockHeader className="bg-[var(--local-secondary)]">
        <CodeBlockSelect>
          <CodeBlockSelectTrigger className="min-w-0 flex-1">
            <CodeBlockSelectValue placeholder="Select file" />
          </CodeBlockSelectTrigger>
          <CodeBlockSelectContent>
            {(item) => (
              <CodeBlockSelectItem key={item.id} value={item.id}>
                <span data-jp-item-field="tabs" data-jp-item-id={item.id} data-jp-field="filename">
                  {item.filename}
                </span>
              </CodeBlockSelectItem>
            )}
          </CodeBlockSelectContent>
        </CodeBlockSelect>
        <CodeBlockCopyButton />
      </CodeBlockHeader>
      <CodeBlockBody>
        {(item) => (
          <CodeBlockItem
            key={item.id}
            value={item.id}
            lineNumbers={lineNumbers}
            data-jp-item-field="tabs"
            data-jp-item-id={item.id}
            data-jp-field="code"
          >
            <CodeBlockContent language={item.language as BundledLanguage} syntaxHighlighting={syntaxHighlighting}>
              {item.code}
            </CodeBlockContent>
          </CodeBlockItem>
        )}
      </CodeBlockBody>
    </CodeBlock>
  );
}

export function CodeBlockView({ data, settings }: CodeBlockSectionViewProps) {
  const lineNumbers = settings?.lineNumbers ?? true;
  const syntaxHighlighting = settings?.syntaxHighlighting ?? true;

  const rootStyle = {
    "--local-bg": "var(--background)",
    "--local-border": "var(--border)",
    "--local-secondary": "var(--secondary)",
  } as CSSProperties;

  return (
    <section className="bg-[var(--local-bg)] py-12 md:py-16" style={rootStyle}>
      <div className="mx-auto max-w-5xl px-6">
        {(data.eyebrow || data.heading || data.description) && (
          <div className="mb-12">
            {data.eyebrow && (
              <p
                className="mb-4 text-xs font-semibold tracking-widest uppercase"
                style={{ color: 'var(--primary)' }}
                data-jp-field="eyebrow"
              >
                {data.eyebrow}
              </p>
            )}
            {data.heading && (
              <h2
                className="text-balance text-4xl leading-tight font-semibold"
                data-jp-field="heading"
              >
                {data.heading}
              </h2>
            )}
            {data.description && (
              <p
                className="mt-6 max-w-2xl leading-relaxed"
                style={{ color: 'var(--muted-foreground)' }}
                data-jp-field="description"
              >
                {data.description}
              </p>
            )}
          </div>
        )}

        <div className={cn(
          "grid gap-4",
          data.columns.length > 1 ? "md:grid-cols-2" : "grid-cols-1",
        )}>
          {data.columns.map((column) => (
            <TerminalColumn
              key={column.id}
              column={column}
              lineNumbers={lineNumbers}
              syntaxHighlighting={syntaxHighlighting}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
