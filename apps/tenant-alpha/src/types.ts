import type { BookDetailData, BookDetailSettings } from '@/components/book-detail';
import type { BooksListData, BooksListSettings } from '@/components/books-list';
import type { EmptyTenantData, EmptyTenantSettings } from '@/components/empty-tenant';
import type { FooterData, FooterSettings } from '@/components/footer';
import type { FormDemoData, FormDemoSettings } from '@/components/form-demo';
import type { Libro } from '@/collections/libri';

export type SectionComponentPropsMap = {
  'book-detail': { data: BookDetailData; settings?: BookDetailSettings };
  'books-list': { data: BooksListData; settings?: BooksListSettings };
  'empty-tenant': { data: EmptyTenantData; settings?: EmptyTenantSettings };
  footer: { data: FooterData; settings?: FooterSettings };
  'form-demo': { data: FormDemoData; settings?: FormDemoSettings };
};

declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    'book-detail': BookDetailData;
    'books-list': BooksListData;
    'empty-tenant': EmptyTenantData;
    footer: FooterData;
    'form-demo': FormDemoData;
  }
  export interface SectionSettingsRegistry {
    'book-detail': BookDetailSettings;
    'books-list': BooksListSettings;
    'empty-tenant': EmptyTenantSettings;
    footer: FooterSettings;
    'form-demo': FormDemoSettings;
  }
  export interface CollectionItemRegistry {
    libri: Libro;
  }
}

export * from '@olonjs/core';
