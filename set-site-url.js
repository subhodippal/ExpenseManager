// Puts your site's full address into the link-preview tags in index.html
// (WhatsApp / Facebook only show the logo + title when the image address is complete).
// Usage:  node set-site-url.js https://yourname.github.io/expense-manager/
const fs = require('fs');
const path = require('path');

let site = (process.argv[2] || '').trim();
if (!/^https:\/\/[^/]+/.test(site)) {
  console.error('Give the full https address of your site, e.g.\n  node set-site-url.js https://yourname.github.io/expense-manager/');
  process.exit(1);
}
if (!site.endsWith('/')) site += '/';

const file = path.join(__dirname, 'index.html');
let html = fs.readFileSync(file, 'utf8');
const set = (attr, name, value) => {
  const re = new RegExp(`(<meta ${attr}="${name}" content=")[^"]*(")`);
  if (!re.test(html)) throw new Error(`meta ${name} not found`);
  html = html.replace(re, `$1${value}$2`);
};
set('property', 'og:url', site);
set('property', 'og:image', site + 'icons/og-image.jpg');
set('name', 'twitter:image', site + 'icons/og-image.jpg');
fs.writeFileSync(file, html);
console.log(`Link preview now points to ${site}\nShare ${site} on WhatsApp to see the logo + title.`);
