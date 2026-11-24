import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repository = process.env.GITHUB_REPOSITORY || '';
const [owner, name] = repository.split('/');
const title = process.env.DOCS_TITLE || name || 'Project';
const projectSite = Boolean(owner && name);
const defaultBase = projectSite && name.toLowerCase() !== (owner + '.github.io').toLowerCase()
  ? '/' + name + '/' : '/';
const base = process.env.DOCS_BASE || defaultBase;
const site = process.env.DOCS_SITE || (owner
  ? 'https://' + owner.toLowerCase() + '.github.io'
  : 'https://example.com');
if (!/^\/(?:[A-Za-z0-9._~-]+\/)*$/.test(base)) {
  throw new Error('DOCS_BASE must be a root-relative directory path ending in /');
}

export default defineConfig({
  srcDir: resolve(here, 'src'),
  // Prerendered server chunks must resolve dependencies from this package.
  outDir: resolve(here, 'dist'),
  cacheDir: resolve(here, '../cache/astro'),
  site,
  base,
  integrations: [starlight({
    title,
    disable404Route: true,
    favicon: '/images/favicon.png',
    // The reference has stable, intentionally ordered groups like Creator Hub.
    customCss: [
      './src/styles/layout.css',
      './src/styles/theme/fallback.css',
      './src/styles/theme/native.css',
      './src/styles/project.css',
      './src/styles/theme/forced-colors.css',
    ],
    social: repository ? [{ icon: 'github', label: 'GitHub', href: 'https://github.com/' + repository }] : [],
    sidebar: [
      { label: 'Overview', link: '/' },
      { label: 'Learn', items: [
        { slug: 'getting-started' },
        { slug: 'configuration' },
        { slug: 'learn/lookup-results' },
        { slug: 'learn/migration' },
      ] },
      { label: 'API reference', items: [
        { slug: 'reference' },
        { label: 'Functions', items: [{ slug: 'reference/functions/register' }] },
        { label: 'Registry object', items: [{ slug: 'reference/registry/get' }] },
        { label: 'Types', items: [
          { slug: 'reference/types/registry' },
          { slug: 'reference/types/resolvable' },
        ] },
      ] },
      { label: 'Resources', items: [
        { slug: 'benchmarks' },
        { slug: 'resources/benchmark-methodology' },
      ] },
    ],
    editLink: projectSite ? { baseUrl: 'https://github.com/' + repository + '/edit/source/content/docs/' } : undefined,
  })],
});
