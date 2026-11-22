import fs from 'node:fs';
import path from 'node:path';

const directory = process.argv[2];
if (!directory) throw new Error('Pass a folder containing GRPK layers 11 and 19 in grpk-<layer>-<page>.json.');
const base = new URL('../data/city/', import.meta.url);
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const city = read(new URL('mazeikiai.json', base));
const buildings = city.buildings.concat(read(new URL('grpk_buildings.json', base)).buildings);
const data = layer => fs.readdirSync(directory).filter(name => name.startsWith('grpk-' + layer + '-'))
  .sort().flatMap(name => read(path.join(directory, name)).features);
const round = number => Math.round(number * 10) / 10;
const [lat, lon] = city.origin;
const project = ([x, y]) => [round((x - lon) * 111319.49 * Math.cos(lat * Math.PI / 180)), round((lat - y) * 111319.49)];
const [minX, maxZ] = project([city.bounds[1], city.bounds[0]]);
const [maxX, minZ] = project([city.bounds[3], city.bounds[2]]);
const bounds = [[minX, maxX], [minZ, maxZ]];
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
const interpolate = (a, b, t) => a.map((n, i) => n + t * (b[i] - n));
const boundsFor = points => [0, 1].map(axis => points.reduce(([lo, hi], p) =>
  [Math.min(lo, p[axis]), Math.max(hi, p[axis])], [Infinity, -Infinity]));
const inside = ([x, y], ring) => {
  let result = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [ax, ay] = ring[i], [bx, by] = ring[j];
    if ((ay > y) !== (by > y) && x < (bx - ax) * (y - ay) / (by - ay) + ax) result = !result;
  }
  return result;
};
function cells(box) {
  const result = [];
  const [[x1, x2], [y1, y2]] = box;
  for (let x = Math.floor(x1 / 40); x <= Math.floor(x2 / 40); x++) {
    for (let y = Math.floor(y1 / 40); y <= Math.floor(y2 / 40); y++) result.push(x + ',' + y);
  }
  return result;
}
function index(map, box, value) {
  for (const key of cells(box)) {
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(value);
  }
}
const near = (map, point) => map.get(cells(point.map(n => [n, n]))[0]) ?? [];
const buildingIndex = new Map();
for (const row of buildings) index(buildingIndex, boundsFor(row[3]), row[3]);
const streets = new Map();
function addStreet(a, b, width) {
  const buffer = width * 0.5 + 1.15;
  index(streets, boundsFor([a, b]).map(([lo, hi]) => [lo - buffer, hi + buffer]), [a, b, buffer]);
}
for (const [width, , , , points] of city.roads) {
  for (let index = 1; index < points.length; index++) addStreet(points[index - 1], points[index], width);
}
function overlap(p, a, b, street, path) {
  const [s, t, radius] = street;
  const v = t.map((n, i) => n - s[i]), w = b.map((n, i) => n - a[i]);
  const length = Math.hypot(...v);
  if (length < 0.01 || Math.abs((v[0] * w[0] + v[1] * w[1]) / length / Math.hypot(...w)) < 0.78) return false;
  const projected = ((p[0] - s[0]) * v[0] + (p[1] - s[1]) * v[1]) / (length * length);
  const clearance = path ? Math.max(1.35, radius - 1.1) : Math.max(2.45, radius);
  return dist(p, interpolate(s, t, Math.min(1, Math.max(0, projected)))) < clearance;
}
function clipRing(ring) {
  for (const axis of [0, 1]) {
    for (const side of [0, 1]) {
      const limit = bounds[axis][side];
      const points = [];
      const contains = point => side === 0 ? point[axis] >= limit : point[axis] <= limit;
      for (let i = 0; i < ring.length; i++) {
        const a = ring[i], b = ring[(i + 1) % ring.length];
        if (contains(a)) points.push(a);
        if (contains(a) !== contains(b)) points.push(interpolate(a, b, (limit - a[axis]) / (b[axis] - a[axis])));
      }
      ring = points;
    }
  }
  return ring.map(p => p.map(round)).filter((p, i, points) => !i || dist(p, points[i - 1]) >= 0.2);
}
const water = [];
const projectedWater = data(19).filter(row => row.attributes.GKODAS === 'hd1' || row.attributes.SHAPE_Area >= 9500);
for (const feature of projectedWater) {
  const largest = feature.geometry.rings[0].slice(0, -1).map(project);
  const points = clipRing(largest);
  if (points.length < 6) continue;
  const box = boundsFor(points);
  const centre = box.map(([lo, hi]) => (lo + hi) * 0.5);
  const flowing = feature.attributes.GKODAS === 'hd1';
  if (!flowing && city.water.some(ring => inside(centre, ring) || points.filter(point => inside(point, ring)).length > points.length * 0.23)) continue;
  water.push({points, flowing, name: feature.attributes.VARDAS ?? ''});
}

const routes = [];
const paved = new Set([1, 2, 3, 5, 6, 7, 9, 13, 15]);
const widths = {1: 11, 2: 8.2, 3: 6.8, 4: 4.8, 5: 6.6, 6: 4.8, 7: 3.8, 8: 3.4, 9: 3.2, 10: 2.9, 11: 2.9, 13: 2.1, 15: 2.8};
for (const feature of data(11)) {
  const source = feature.attributes;
  const type = source.TIPAS;
  if (!(type in widths) || Number(source.LYGMUO) < 0) continue;
  const width = source.PLOTIS >= 1.6 && source.PLOTIS <= 12 ? source.PLOTIS : widths[type];
  const path = type === 13 || type === 15;
  for (const line of feature.geometry.paths) {
    let chain = [];
    const flush = () => {
      if (chain.length > 1 && chain.slice(1).reduce((sum, point, i) => sum + dist(point, chain[i]), 0) > (path ? 7.0 : 10.5)) {
        routes.push([round(width), !path && paved.has(type) ? 1 : 0, [1, 2, 3, 5].includes(type) ? 1 : 0, source.VARDAS ?? '', chain,
          {style: path ? 'pavers' : paved.has(type) ? '' : 'gravel'}]);
        for (let i = 1; i < chain.length; i++) addStreet(chain[i - 1], chain[i], width);
      }
      chain = [];
    };
    const points = line.map(project);
    for (let i = 1; i < points.length; i++) {
      const a = points[i - 1], b = points[i];
      const pieces = Math.ceil(dist(a, b) / 9);
      for (let j = 0; j < pieces; j++) {
        const start = interpolate(a, b, j / pieces).map(round), end = interpolate(a, b, (j + 1) / pieces).map(round);
        const middle = interpolate(start, end, 0.5);
        const valid = middle.every((n, axis) => n >= bounds[axis][0] && n <= bounds[axis][1])
          && !near(streets, middle).some(road => overlap(middle, a, b, road, path))
          && ![start, middle, end].some(point => near(buildingIndex, point).some(poly => inside(point, poly)))
          && !water.some(row => inside(middle, row.points));
        if (!valid) { flush(); continue; }
        if (!chain.length) chain.push(start);
        chain.push(end);
      }
    }
    flush();
  }
}
fs.writeFileSync(new URL('grpk_streets.json', base), JSON.stringify(routes));
fs.writeFileSync(new URL('river_corridor.json', base), JSON.stringify(water));
console.log(routes.length + ' street sections and ' + water.length + ' additional waterways');

