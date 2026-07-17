import { useEffect } from 'react';
import type { PageMeta } from '@olonjs/core';

export const useDocumentMeta = (meta: PageMeta): void => {
  useEffect(() => {
    document.title = meta.title;
    let metaDescription = document.querySelector('meta[name="description"]');
    if (!metaDescription) {
      metaDescription = document.createElement('meta');
      metaDescription.setAttribute('name', 'description');
      document.head.appendChild(metaDescription);
    }
    metaDescription.setAttribute('content', meta.description);
  }, [meta.title, meta.description]);
};
