import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';

export const HeaderLinkSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
});

/** Matches authored `site.json` header.data shape for the Next demo tenant. */
export const HeaderSchema = BaseSectionData.extend({
  logoText: z.string().describe('ui:text'),
  badge: z.string().optional().describe('ui:text'),
  links: z.array(HeaderLinkSchema).default([]).describe('ui:list'),
  ctaLabel: z.string().optional().describe('ui:text'),
  ctaHref: z.string().optional().describe('ui:text'),
  signinHref: z.string().optional().describe('ui:text'),
});

export const HeaderSettingsSchema = z.object({});
