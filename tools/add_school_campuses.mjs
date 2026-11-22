import { readFileSync, writeFileSync } from 'node:fs';

const project = new URL('../', import.meta.url);
const files = process.argv.slice(2);
if (files.length === 0) throw new Error('Pass the Mažeikiai OpenStreetMap XML tiles.');

const city = JSON.parse(readFileSync(new URL('data/city/mazeikiai.json', project)));
const [latitude, longitude] = city.origin;
const lonScale = 111319.49 * Math.cos(latitude * Math.PI / 180);
const municipality = 'https://www.mazeikiai.lt/savivalda/administracine-informacija/veiklos-sritys/svietimas/svietimo-istaigos';
const schools = new Map([
  [400224105, ['Gabijos gimnazija', '#b9b8ad', '#777f81', 'panel', 4]],
  [400549729, ['Merkelio Račkausko gimnazija', '#c99b77', '#ded5c0', 'historic', 3]],
  [400217864, ['Ventos progimnazija', '#d2c9b6', '#826851', 'panel', 3]],
  [400213123, ['Kalnėnų progimnazija', '#c2bdb0', '#676d74', 'panel', 3]],
  [542501360, ['Pavasario progimnazija', '#d3c1a6', '#985f49', 'panel', 3]],
  [400552247, ['Senamiesčio progimnazija', '#c6ad96', '#745d60', 'panel', 3]],
  [400223007, ['Sodų pagrindinė mokykla', '#c0bcb0', '#996b54', 'panel', 3]],
  [400549912, ['Jievaro pagrindinė mokykla', '#c9c5a9', '#596f65', 'panel', 2]],
  [399992930, ['Kazimiero Jagmino pradinė mokykla', '#d0b59b', '#765d4c', 'panel', 2]],
  [400221628, ['Vyturio pradinė mokykla', '#c4ba9c', '#5e786e', 'panel', 2]],
  [400224379, ['Žiburėlio pradinė mokykla', '#d2bcad', '#956d59', 'panel', 2]],
  [400214113, ['Mažeikių politechnikos mokykla', '#b7b6ae', '#627780', 'panel', 3]],
  [400218543, ['Dailės ir choreografijos mokykla', '#ccbeb1', '#726d8a', 'panel', 2]],
  [400550760, ['Vytauto Klovos muzikos mokykla', '#dedbd0', '#6b756c', 'panel', 3]],
  [267473643, ['Vaikų ir jaunimo daugiafunkcis centras', '#c7bcb0', '#8b6357', 'panel', 2]],
  [543769242, ['Mažeikių moksleivių namai', '#b6aea3', '#795746', 'panel', 2]],
  [400553398, ['Kregždutės mokykla', '#d1c1aa', '#7d9175', 'panel', 2]]
]);
const nodes = new Map();
const ways = new Map();
const relations = new Map();
const attributes = text => Object.fromEntries(Array.from(text.matchAll(/([-\w:]+)="([^"]*)"/g), ([, name, value]) => [name, value]));
const entity = value => value.replace(/&(amp|lt|gt|quot|apos|#\d+);/g, (match, name) =>
  name.startsWith('#') ? String.fromCodePoint(Number(name.slice(1))) : ({ amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" })[name] ?? match);
const tags = text => Object.fromEntries(Array.from(text.matchAll(/<tag\b([^>]+?)\/>/g), ([, raw]) => {
  const tag = attributes(raw);
  return [tag.k, entity(tag.v)];
}));
const round = value => Math.round(value * 10) / 10;

for (const file of files) {
  const xml = readFileSync(file, 'utf8');
  for (const [, raw] of xml.matchAll(/<node\b([^>]+)/g)) {
    const node = attributes(raw);
    nodes.set(Number(node.id), [round((Number(node.lon) - longitude) * lonScale), round((latitude - Number(node.lat)) * 111319.49)]);
  }
  for (const [, raw, body] of xml.matchAll(/<way\b([^>]+)>([\s\S]*?)<\/way>/g)) {
    const id = Number(attributes(raw).id);
    ways.set(id, { id, tags: tags(body), refs: Array.from(body.matchAll(/<nd ref="(\d+)"/g), ([, ref]) => Number(ref)) });
  }
  for (const [, raw, body] of xml.matchAll(/<relation\b([^>]+)>([\s\S]*?)<\/relation>/g)) {
    const id = Number(attributes(raw).id);
    relations.set(id, { id, tags: tags(body), members: Array.from(body.matchAll(/<member\b([^>]+?)\/>/g), ([, member]) => attributes(member)) });
  }
}

function projected(refs) {
  if (refs.length < 4 || refs[0] !== refs.at(-1)) return [];
  const outline = refs.slice(0, -1).map(id => nodes.get(id));
  return outline.every(point => point && Number.isFinite(point[0]) && Number.isFinite(point[1])) ? outline : [];
}

function area(outline) {
  return Math.abs(outline.reduce((sum, a, i) => {
    const b = outline[(i + 1) % outline.length];
    return sum + a[0] * b[1] - a[1] * b[0];
  }, 0)) * 0.5;
}

function contains(outline, [x, y]) {
  let inside = false;
  for (let i = 0, previous = outline.length - 1; i < outline.length; previous = i++) {
    const [x1, y1] = outline[i];
    const [x2, y2] = outline[previous];
    if ((y1 > y) !== (y2 > y) && x < (x2 - x1) * (y - y1) / (y2 - y1) + x1) inside = !inside;
  }
  return inside;
}

function center(outline) {
  return [0, 1].map(axis => round(outline.reduce((sum, point) => sum + point[axis], 0) / outline.length));
}

const documents = city.buildings.map(row => ({ id: row[0], outline: row[3], size: area(row[3]) }));
const known = new Set(documents.map(row => row.id));
const supplement = [];
const campuses = [];
for (const [id, [name, wall, accent, style, floors]] of schools) {
  const way = ways.get(id);
  const site = way ? projected(way.refs) : [];
  if (site.length < 3) throw new Error(`Missing campus outline for ${name}.`);

  const present = docsInSite(documents, site);
  for (const relation of relations.values()) {
    if (!relation.tags.building) continue;
    const outer = relation.members.filter(member => member.type === 'way' && member.role === 'outer');
    if (outer.length !== 1) continue;
    const shell = ways.get(Number(outer[0].ref));
    if (shell) includeNew(shell);
  }
  for (const candidate of ways.values()) {
    if (candidate.tags.building) includeNew(candidate);
  }

  present.sort((a, b) => b.size - a.size);
  if (present.length === 0) throw new Error(`No building footprint for ${name}.`);
  const buildingIds = present.map(row => row.id);
  campuses.push({ id, name, point: center(present[0].outline), main: buildingIds[0], buildings: buildingIds, wall, accent, style, floors });

  function includeNew(candidate) {
    if (known.has(candidate.id)) return;
    const outline = projected(candidate.refs);
    const size = area(outline);
    if (size < 43 || !contains(site, center(outline))) return;
    if (present.some(row => contains(row.outline, center(outline)) || contains(outline, center(row.outline)))) return;
    known.add(candidate.id);
    present.push({ id: candidate.id, outline, size });
    supplement.push([candidate.id, Math.round(floors * 3.1 * 10) / 10, 2, outline, name, 0]);
  }
}

function docsInSite(records, site) {
  return records.filter(row => row.size >= 43 && contains(site, center(row.outline)));
}

writeFileSync(new URL('data/city/schools.json', project), JSON.stringify({
  attribution: '© OpenStreetMap contributors, ODbL 1.0',
  sources: ['https://www.openstreetmap.org/copyright', municipality],
  campuses,
  buildings: supplement
}));
for (const campus of campuses) console.log(`${campus.name}: ${campus.buildings.join(', ')} at ${campus.point.join(', ')}`);
console.log(`${campuses.length} campuses, ${supplement.length} added footprints.`);
