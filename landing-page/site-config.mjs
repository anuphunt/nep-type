// Keep preview and local builds out of search, even with a production SITE_URL.
export function siteConfig(env = process.env) {
  const url = new URL(env.SITE_URL || 'https://neptype.com');
  if (url.protocol !== 'https:' || url.username || url.password || url.pathname !== '/' || url.search || url.hash || url.port || url.hostname === 'localhost' || /^[\d.]+$/.test(url.hostname) || url.hostname.endsWith('.netlify.app')) {
    throw Error('SITE_URL must be the public HTTPS canonical origin, without a path, credentials, or a preview hostname.');
  }
  return {origin: url.origin, production: env.CONTEXT === 'production'};
}
