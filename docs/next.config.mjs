import { createMDX } from 'fumadocs-mdx/next';

// Static export for GitHub Pages. When building for a project Pages site
// (everjust-dev.github.io/usesend-email) the workflow sets
// NEXT_PUBLIC_BASE_PATH=/usesend-email; for a custom domain leave it empty.
const basePath = process.env.NEXT_PUBLIC_BASE_PATH || '';

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
