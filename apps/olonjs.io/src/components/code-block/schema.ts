import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';

export const CodeBlockTabSchema = BaseArrayItem.extend({
  filename: z.string().describe('ui:text'),
  /** Shiki / bundled language id (e.g. `typescript`, `tsx`, `json`). */
  language: z.string().describe('ui:text'),
  code: z.string().describe('ui:textarea'),
});

export const CodeBlockColumnSchema = BaseArrayItem.extend({
  tabs: z.array(CodeBlockTabSchema).min(1).describe('ui:list'),
});

export const CodeBlockSettingsSchema = z.object({
  lineNumbers: z.boolean().default(true),
  syntaxHighlighting: z.boolean().default(true),
});

export const CodeBlockSchema = BaseSectionData.extend({
  eyebrow: z.string().optional().describe('ui:text'),
  heading: z.string().optional().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  columns: z.array(CodeBlockColumnSchema).min(1).max(2).describe('ui:list'),
});
