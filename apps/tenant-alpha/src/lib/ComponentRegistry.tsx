import type { SectionType } from '@/types';
import type { SectionComponentPropsMap } from '@/types';
import { BookDetailView } from '@/components/book-detail';
import { BooksListView } from '@/components/books-list';
import { EmptyTenantView } from '@/components/empty-tenant';
import { FooterView } from '@/components/footer';
import { FormDemoView } from '@/components/form-demo';

export const ComponentRegistry: {
  [K in SectionType]: React.FC<SectionComponentPropsMap[K]>;
} = {
  'book-detail': BookDetailView as React.FC<SectionComponentPropsMap['book-detail']>,
  'books-list': BooksListView as React.FC<SectionComponentPropsMap['books-list']>,
  'empty-tenant': EmptyTenantView as React.FC<SectionComponentPropsMap['empty-tenant']>,
  footer: FooterView as React.FC<SectionComponentPropsMap['footer']>,
  'form-demo': FormDemoView as React.FC<SectionComponentPropsMap['form-demo']>,
};
