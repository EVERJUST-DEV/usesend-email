import { source } from '@/lib/source';
import { createFromSource } from 'fumadocs-core/search/server';

// Static search index (built at export time) so search works on GitHub Pages
// without a server. The client is configured with search type "static" in
// app/layout.tsx.
export const revalidate = false;

export const { staticGET: GET } = createFromSource(source, {
  buildIndex: (page) => {
    const sd = page.data.structuredData ?? { headings: [], contents: [] };
    return {
      title: page.data.title,
      description: page.data.description,
      structuredData: sd,
      id: page.url,
      url: page.url,
    };
  },
});
