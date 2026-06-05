/**
 * Compress blog images in-place.
 * Usage: node scripts/compress-images.js <folder>
 *   e.g. node scripts/compress-images.js public/images/chogori-jimbocho
 *
 * Targets: max 1600px wide, JPEG quality 78, progressive.
 * Skips files already under MAX_BYTES.
 */
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const MAX_WIDTH = 1600;
const QUALITY = 78;
const MAX_BYTES = 400 * 1024; // 400 KB — skip if already small

async function compressOne(file) {
  const buf = fs.readFileSync(file);
  if (buf.length < MAX_BYTES) {
    console.log(`SKIP   ${path.basename(file)} (${(buf.length / 1024).toFixed(0)} KB)`);
    return;
  }
  const out = await sharp(buf)
    .rotate() // honor EXIF orientation
    .resize({ width: MAX_WIDTH, withoutEnlargement: true })
    .jpeg({ quality: QUALITY, progressive: true, mozjpeg: true })
    .toBuffer();
  const before = (buf.length / 1024).toFixed(0);
  const after = (out.length / 1024).toFixed(0);
  fs.writeFileSync(file, out);
  console.log(`COMP   ${path.basename(file)}  ${before} KB → ${after} KB`);
}

(async () => {
  const target = process.argv[2];
  if (!target) {
    console.error('Usage: node scripts/compress-images.js <folder>');
    process.exit(1);
  }
  const abs = path.resolve(target);
  const stat = fs.statSync(abs);
  const files = stat.isDirectory()
    ? fs.readdirSync(abs).filter((f) => /\.(jpe?g|png)$/i.test(f)).map((f) => path.join(abs, f))
    : [abs];
  for (const f of files) {
    try { await compressOne(f); } catch (e) { console.error(`FAIL   ${f}: ${e.message}`); }
  }
})();
