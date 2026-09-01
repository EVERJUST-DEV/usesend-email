import { docs } from 'collections/server';
import { loader } from 'fumadocs-core/source';

export const source = loader({
  // Docs are mounted at the app root; the whole site is served under the /docs
  // base path (see next.config.mjs), giving clean mail.everjust.app/docs URLs.
  baseUrl: '/',
  source: docs.toFumadocsSource(),
});
