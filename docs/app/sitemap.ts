import { MetadataRoute } from 'next';
import { source } from '@/lib/source';

// Required for `output: export` — evaluate the sitemap once at build time.
export const dynamic = 'force-static';

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl =
    process.env.NEXT_PUBLIC_SITE_URL || 'https://everjust-dev.github.io/usesend-email';
  const now = new Date();

  // Get all documentation pages from Fumadocs
  const pages = source.getPages().map((page) => ({
    url: `${baseUrl}${page.url}`,
    lastModified: now,
    changeFrequency: 'weekly' as const,
    priority: page.url === '/docs' ? 0.9
           : page.url.startsWith('/docs/channels') ? 0.8
           : page.url.startsWith('/docs/skills') ? 0.8
           : page.url.startsWith('/docs/integrations') ? 0.8
           : 0.7,
  }));

  return [
    {
      url: baseUrl,
      lastModified: now,
      changeFrequency: 'weekly',
      priority: 1,
    },
    ...pages,
  ];
}
