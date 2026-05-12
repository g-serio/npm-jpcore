import type { AddSectionConfig } from '@olonjs/core';

const addableSectionTypes = ['empty-tenant', 'form-demo'] as const;

const sectionTypeLabels: Record<string, string> = {
  'empty-tenant': 'Empty Tenant',
  'form-demo': 'Form Demo',
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
    default:
      return {};
  }
}

export const addSectionConfig: AddSectionConfig = {
  addableSectionTypes: [...addableSectionTypes],
  sectionTypeLabels,
  getDefaultSectionData,
};
