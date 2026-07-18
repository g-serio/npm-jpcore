import type { Dispatch, SetStateAction, MutableRefObject } from 'react';
import type { JsonPagesConfig } from '@olonjs/core';
import type { CloudLoadFailure, ContentMode } from '@/lib/cloud/types';
import type { MenuConfig, PageConfig, SiteConfig } from '@/types';

export type BootstrapContentSetters = {
  setPages: Dispatch<SetStateAction<Record<string, PageConfig>>>;
  setSiteConfig: Dispatch<SetStateAction<SiteConfig>>;
  setMenuConfig: Dispatch<SetStateAction<MenuConfig>>;
  setCollections: Dispatch<SetStateAction<NonNullable<JsonPagesConfig['collections']>>>;
  setContentMode: Dispatch<SetStateAction<ContentMode>>;
  setContentFallback: Dispatch<SetStateAction<CloudLoadFailure | null>>;
  setShowTopProgress: Dispatch<SetStateAction<boolean>>;
  setHasInitialCloudResolved: Dispatch<SetStateAction<boolean>>;
};

export type BootstrapInFlightRef = MutableRefObject<Promise<void> | null>;
