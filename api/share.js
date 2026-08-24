const fs = require('fs');
const path = require('path');

// Escapes text so it can be safely placed inside HTML attribute values / text nodes.
// Prevents stored data (store title/description/logoUrl) from breaking out of the
// meta tags and injecting markup or scripts into the response.
function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Serialises a value for an inline <script> block. escapeHtml must NOT be used
// here: HTML entities are not decoded inside <script>, so it would corrupt the
// JSON. What matters instead is that the output can never produce a sequence
// that closes the script tag or breaks the JS parser.
function toScriptJson(value) {
  return JSON.stringify(value)
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/&/g, '\\u0026')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

// Values below come from the database and are written into a <style> block, so
// anything outside this allowlist (quotes, braces, semicolons, angle brackets)
// is rejected in favour of the default. Covers hex colors, rgb()/rgba(),
// linear-gradient(...) and length units.
function safeCssValue(value, fallback) {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > 200) return fallback;
  return /^[#a-zA-Z0-9 ,.%()\-]+$/.test(trimmed) ? trimmed : fallback;
}

// Mirrors the theme variables cliente.html derives in applyConfig(), so the
// skeleton loader paints in the store brand color on the very first frame
// instead of flashing the default palette first.
function buildThemeStyle(config) {
  const bgType = config.bgType || 'solid';
  let bg = safeCssValue(config.bgColor, '#ffffff');
  if (bgType === 'gradient') {
    bg = safeCssValue(config.bgGradient, 'linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%)');
  }

  const text = safeCssValue(config.textColor, '#0f172a');
  const highlight = safeCssValue(config.themeColor, '#7c3aed');
  const btnBg = safeCssValue(config.btnColor, '#ffffff');
  const btnText = safeCssValue(config.btnTextColor, '#0f172a');
  const btnRadius = safeCssValue(config.btnBorderRadius, '30px');

  const isHex6 = (c) => /^#[0-9a-fA-F]{6}$/.test(c);
  const textSoft = isHex6(text) ? text + 'b3' : text;
  const pillBg = isHex6(highlight) ? highlight + '12' : highlight;

  return `<style>:root{` +
    `--bg:${bg};` +
    `--navy:${text};--navy-soft:${textSoft};` +
    `--gold-deep:${highlight};--theme-color:${highlight};--pill-bg:${pillBg};` +
    `--btn-bg:${btnBg};--btn-text:${btnText};--btn-radius:${btnRadius};` +
    `}</style>`;
}

// A config far larger than this is not worth inlining — it would slow the HTML
// down more than the round trip it saves. The client then falls back to
// fetching it itself, exactly as before.
const MAX_INLINE_CONFIG_BYTES = 256 * 1024;

export default async function handler(req, res) {
  const { store } = req.query;

  if (!store) {
    res.status(404).send("Store not specified");
    return;
  }

  // Supabase REST configuration
  const supabaseUrl = "https://lujsstahllhcrkfgjmcw.supabase.co";
  const supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1anNzdGFobGxoY3JrZmdqbWN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ4OTk2NzMsImV4cCI6MjEwMDQ3NTY3M30.Hz5792fPykt248SHcQBhxKb0yxfZsBLxXUKvXNKuppc";

  let title = store;
  let description = "Confira nossos links úteis!";
  let logoUrl = "https://lujsstahllhcrkfgjmcw.supabase.co/storage/v1/object/public/logos/logo.png";
  let storeConfig = null;

  try {
    // Fetch the store config from Supabase directly via REST API (extremely fast, zero overhead)
    const response = await fetch(`${supabaseUrl}/rest/v1/stores?id=eq.${encodeURIComponent(store)}&select=config`, {
      headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${supabaseKey}`
      }
    });

    if (response.ok) {
      const data = await response.json();
      if (data && data.length > 0) {
        const storeData = data[0];
        let parsedConfig = storeData.config;
        if (typeof parsedConfig === 'string') {
          parsedConfig = JSON.parse(parsedConfig);
        }
        if (parsedConfig) {
          title = parsedConfig.title || store;
          description = parsedConfig.description || "Confira nossos links úteis abaixo.";
          logoUrl = parsedConfig.logoUrl || logoUrl;
          storeConfig = parsedConfig;
        }
      }
    }
  } catch (err) {
    console.error("Error fetching store info for social preview:", err);
  }

  try {
    // Read the static cliente.html template file from process cwd
    const filePath = path.join(process.cwd(), 'cliente.html');
    let html = fs.readFileSync(filePath, 'utf8');

    // Escape everything that came from the database (or the URL) before it touches
    // the HTML string below — otherwise a store title/description containing markup
    // could inject a script into every visitor's page (reflected XSS).
    const safeTitle = escapeHtml(title);
    const safeDescription = escapeHtml(description);
    const safeLogoUrl = escapeHtml(logoUrl);
    const safeStoreUrl = encodeURIComponent(store);

    // Create custom Open Graph meta tags to feed to WhatsApp, Facebook, Telegram crawlers
    const metaTags = `
  <title>${safeTitle} — Links</title>
  <meta name="description" content="${safeDescription}">
  <!-- Open Graph / Facebook / WhatsApp -->
  <meta property="og:type" content="website">
  <meta property="og:title" content="${safeTitle}">
  <meta property="og:description" content="${safeDescription}">
  <meta property="og:image" content="${safeLogoUrl}">
  <meta property="og:url" content="https://linksvi.vercel.app/${safeStoreUrl}">
  <!-- Twitter -->
  <meta property="twitter:card" content="summary_large_image">
  <meta property="twitter:title" content="${safeTitle}">
  <meta property="twitter:description" content="${safeDescription}">
  <meta property="twitter:image" content="${safeLogoUrl}">
`;

    // Above-the-fold assets. Starting these with the HTML parse instead of after
    // the page scripts run is what keeps the logo from arriving late.
    let preloads = `  <link rel="preload" as="image" href="${safeLogoUrl}" fetchpriority="high">\n`;
    if (storeConfig && storeConfig.bgType === 'image' && storeConfig.bgImageUrl) {
      preloads += `  <link rel="preload" as="image" href="${escapeHtml(storeConfig.bgImageUrl)}">\n`;
    }

    // Inline the config the client would otherwise fetch from Supabase itself.
    // We already paid for that round trip above, from the edge — repeating it
    // from the visitor's phone is what made the page wait before rendering.
    let inlineConfig = '';
    if (storeConfig) {
      const serialised = toScriptJson(storeConfig);
      if (serialised.length <= MAX_INLINE_CONFIG_BYTES) {
        inlineConfig = `${buildThemeStyle(storeConfig)}\n  <script>window.__STORE_CONFIG__=${serialised};</script>\n`;
      }
    }

    // Remove the static title tag from cliente.html to prevent duplicate titles
    html = html.replace(/<title>.*?<\/title>/gi, '');

    // Inject the new head content. The replacement is given as a function so that
    // a `$&` or `$'` inside a store title/description is treated as literal text
    // rather than as a String.replace substitution pattern.
    const headExtras = metaTags + preloads + inlineConfig;
    html = html.replace('<head>', () => '<head>' + headExtras);

    // Return the dynamic HTML
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate=30'); // Cache at edge for speed
    res.status(200).send(html);
  } catch (err) {
    console.error("Error reading cliente.html:", err);
    res.status(500).send("Internal Server Error");
  }
}
