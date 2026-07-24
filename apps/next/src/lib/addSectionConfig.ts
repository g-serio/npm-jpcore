import type { AddSectionConfig } from '@olonjs/core';

const addableSectionTypes = ['authors-list', 'book-detail', 'books-list', 'empty-tenant', 'footer', 'form-demo'] as const;

const sectionTypeLabels: Record<string, string> = {
  'authors-list': 'Authors List',
  'book-detail': 'Book Detail',
  'books-list': 'Books List',
  'empty-tenant': 'Empty Tenant',
  footer: 'Footer',
  'form-demo': 'Form Demo',
};

function getDefaultSectionData(type: string): Record<string, unknown> {
  switch (type) {
    case 'authors-list':
      return {
        eyebrow: 'Collection demo',
        title: 'Authors',
        description: 'Authors loaded from the autori collection.',
        items: { $ref: '../collections/autori/autori.json' },
      };
    case 'book-detail':
      return {
        item: { $ref: 'collection:current' },
        backLabel: 'Torna ai libri',
      };
    case 'books-list':
      return {
        eyebrow: 'Collection demo',
        title: 'Libri',
        description: 'Catalogo dimostrativo alimentato dalla collection libri.',
        items: { $ref: '../collections/libri/libri.json' },
        pageSize: 10,
      };
    case 'empty-tenant':
      return {
        title: 'Your tenant is empty.',
        description: 'Create your first page to start building your site.',
      };
    case 'footer':
      return {
        brandText: 'OlonJS',
        description: 'AI-native content infrastructure for deterministic, git-backed sites.',
        copyright: '© 2026 OlonJS',
        links: [],
        designSystemHref: '',
      };
    case 'form-demo':
      return {
        title: 'Contattaci',
        description: 'Compila il modulo e ti risponderemo al più presto.',
        recipientEmail: '',
        submitLabel: 'Invia',
        successMessage: 'Richiesta inviata con successo.',
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
