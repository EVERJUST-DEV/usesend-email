import { createMDX } from 'fumadocs-mdx/next';

// Static export served under /docs on the app host (mail.everjust.app/docs),
// behind an ALB path rule. Default base path is /docs; override with
// NEXT_PUBLIC_BASE_PATH (set it to "" to serve at a domain root instead).
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? '/docs';

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  output: 'export',
  trailingSlash: true,
  images: { unoptimized: true },
  basePath,
  assetPrefix: basePath || undefined,
  env: { NEXT_PUBLIC_BASE_PATH: basePath },
};

const withMDX = createMDX();

export default withMDX(config);
