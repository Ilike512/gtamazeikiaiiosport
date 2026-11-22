import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const project = new URL('../', import.meta.url);
const [firstPage, ...morePages] = process.argv.slice(2);
if (!firstPage) throw new Error('Pass one or more GRPK building layer query JSON files.');

const streetMap = JSON.parse(readFileSync(new URL('data/city/mazeikiai.json', project)));
const [latitude, longitude] = streetMap.origin;
const metresPerLongitude = 111319.49 * Math.cos(latitude * Math.PI / 180);
const projected = ([lon, lat]) => [
  Math.round((lon - longitude) * metresPerLongitude * 10) / 10,
  Math.round((latitude - lat) * 111319.49 * 10) / 10
];

function bounds(points, margin = 0) {
  return [Math.min(...points.map(p => p[0])) - margin, Math.min(...points.map(p => p[1])) - margin,
    Math.max(...points.map(p => p[0])) + margin, Math.max(...points.map(p => p[1])) + margin];
}

function intersects(a, b) {
  return a[0] <= b[2] && a[2] >= b[0] && a[1] <= b[3] && a[3] >= b[1];
}

function center(outline) {
  return [0, 1].map(axis => outline.reduce((sum, point) => sum + point[axis], 0) / outline.length);
}

function contains(outline, [x, y]) {
  let inside = false;
  for (let i = 0, previous = outline.length - 1; i < outline.length; previous = i++) {
    const [a, b] = outline[i];
    const [c, d] = outline[previous];
    if ((b > y) !== (d > y) && x < (c - a) * (y - b) / (d - b) + a) inside = !inside;
  }
  return inside;
}

function crosses(a, b, c, d) {
  const sign = (from, to, point) => (to[0] - from[0]) * (point[1] - from[1]) - (to[1] - from[1]) * (point[0] - from[0]);
  return sign(a, b, c) * sign(a, b, d) < -0.005 && sign(c, d, a) * sign(c, d, b) < -0.005;
}

function overlaps(left, right) {
  if (contains(left, center(right)) || contains(right, center(left))) return true;
  for (let a = 0; a < left.length; a++) {
    const next = left[(a + 1) % left.length];
    for (let b = 0; b < right.length; b++) {
      if (crosses(left[a], next, right[b], right[(b + 1) % right.length])) return true;
    }
  }
  return false;
}

function area(points) {
  return Math.abs(points.reduce((sum, a, i) => {
    const b = points[(i + 1) % points.length];
    return sum + a[0] * b[1] - a[1] * b[0];
  }, 0)) / 2;
}

function segmentDistance2(point, a, b) {
  const x = b[0] - a[0];
  const z = b[1] - a[1];
  const factor = Math.max(0, Math.min(1, ((point[0] - a[0]) * x + (point[1] - a[1]) * z) / (x * x + z * z || 1)));
  return (point[0] - a[0] - factor * x) ** 2 + (point[1] - a[1] - factor * z) ** 2;
}

const output = new URL('data/city/grpk_buildings.json', project);
const schoolFile = new URL('data/city/schools.json', project);
const schoolOutlines = existsSync(schoolFile) ? JSON.parse(readFileSync(schoolFile)).buildings.map(row => row[3]) : [];
const existingSupplement = existsSync(output) ? JSON.parse(readFileSync(output)).buildings : [];
const added = existingSupplement.filter(row => !schoolOutlines.some(outline =>
  contains(outline, center(row[3])) || contains(row[3], center(outline))
));
const originalCount = added.length;
const existing = [...streetMap.buildings.map(row => row[3]), ...added.map(row => row[3]), ...schoolOutlines]
  .map(outline => ({ outline, extent: bounds(outline) }));
const streets = streetMap.roads.filter(row => row[1] && row[0] >= 4.5).flatMap(row =>
  row[4].slice(1).map((b, i) => {
    const a = row[4][i];
    const clearance = row[0] * 0.5 + (row[2] ? 1.0 : 0.65);
    return { a, b, clearance, extent: bounds([a, b], clearance) };
  })
);
const seen = new Set(added.map(row => -row[0]));
for (const file of [firstPage, ...morePages]) {
  const page = JSON.parse(readFileSync(file));
  if (page.spatialReference?.wkid !== 4326 || !Array.isArray(page.features)) {
    throw new Error(`Expected WGS84 ArcGIS building features in ${file}.`);
  }
  for (const feature of page.features) {
    const id = feature.attributes.OBJECTID;
    if (seen.has(id)) continue;
    seen.add(id);
    const rings = feature.geometry?.rings?.map(ring => ring.slice(0, -1).map(projected)) ?? [];
    rings.sort((a, b) => area(b) - area(a));
    const footprint = rings[0];
    if (!footprint || footprint.length < 3 || area(footprint) < 6.5) continue;
    const extent = bounds(footprint);
    if (existing.some(other => intersects(extent, other.extent) && overlaps(footprint, other.outline))) continue;
    if (streets.some(road => intersects(road.extent, extent) &&
      (contains(footprint, road.a) || contains(footprint, road.b) ||
        footprint.some(point => segmentDistance2(point, road.a, road.b) < road.clearance ** 2)))) continue;
    const size = area(footprint);
    const height = size < 25 ? 2.55 : (size < 95 ? 3.2 : (size < 265 ? 5.8 : 8.0));
    added.push([-id, height, size < 25 ? 1 : (size > 265 ? 2 : 0), footprint, '', size >= 25 && size < 145 && footprint.length === 4 ? 1 : 0]);
    existing.push({ outline: footprint, extent });
  }
}

const data = {
  attribution: 'GRPK © Lietuvos Respublikos aplinkos ministerija, geoportal.lt',
  license: 'CC BY 4.0',
  source: 'https://data.gov.lt/datasets/3424/',
  buildings: added
};
writeFileSync(output, JSON.stringify(data));
console.log(`Added ${added.length - originalCount} building footprints (${added.length} total).`);
