const fs = require('fs');
const path = require('path');

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

    // Create custom Open Graph meta tags to feed to WhatsApp, Facebook, Telegram crawlers
    const metaTags = `
  <title>${title} — Links</title>
  <meta name="description" content="${description}">
  <!-- Open Graph / Facebook / WhatsApp -->
  <meta property="og:type" content="website">
  <meta property="og:title" content="${title}">
  <meta property="og:description" content="${description}">
  <meta property="og:image" content="${logoUrl}">
  <meta property="og:url" content="https://linksvi.vercel.app/${store}">
  <!-- Twitter -->
  <meta property="twitter:card" content="summary_large_image">
  <meta property="twitter:title" content="${title}">
  <meta property="twitter:description" content="${description}">
  <meta property="twitter:image" content="${logoUrl}">
`;

    // Remove the static title tag from cliente.html to prevent duplicate titles
    html = html.replace(/<title>.*?<\/title>/gi, '');

    // Inject the new meta tags right inside the <head> block
    html = html.replace('<head>', `<head>${metaTags}`);

    // Return the dynamic HTML
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate=30'); // Cache at edge for speed
    res.status(200).send(html);
  } catch (err) {
    console.error("Error reading cliente.html:", err);
    res.status(500).send("Internal Server Error");
  }
}
