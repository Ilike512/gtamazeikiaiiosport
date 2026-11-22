import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const inputFolder = process.argv[2];
if (!inputFolder) {
  throw new Error('Usage: node tools/build_city.mjs <folder containing OSM XML tiles>');
}
const nodes=new Map(), ways=new Map(), relations=new Map();
function decode(value){return value.replace(/&(amp|lt|gt|quot|apos|#x[\da-f]+|#\d+);/gi,(_,x)=>x[0]==='#'?String.fromCodePoint(x[1]==='x'?parseInt(x.slice(2),16):Number(x.slice(1))):({amp:'&',lt:'<',gt:'>',quot:'"',apos:"'"}[x]??x));}
const attrib = text => Object.fromEntries(Array.from(text.matchAll(/([-\w:]+)="([^"]*)"/g),([_,key,value])=>[key,decode(value)]));
for(const name of fs.readdirSync(inputFolder).filter(x=>x.endsWith('.osm')).sort()){
 const xml=fs.readFileSync(path.join(inputFolder, name),'utf8');
 for(const match of xml.matchAll(/<node\b([^>]*?)(?:\/>|>([\s\S]*?)<\/node>)/g)){
   const a=attrib(match[1]); if(!a.lat)continue;
   const tags=Object.fromEntries([...((match[2]??'').matchAll(/<tag ([^>]+?)\/>/g))].map(m=>{const b=attrib(m[1]);return[b.k,b.v];}));
   nodes.set(a.id,{lat:+a.lat,lon:+a.lon,tags});
 }
 for(const match of xml.matchAll(/<way\b([^>]*?)>([\s\S]*?)<\/way>/g)){
   const a=attrib(match[1]); const refs=[...match[2].matchAll(/<nd ref="(\d+)"/g)].map(m=>m[1]);
   const tags=Object.fromEntries([...match[2].matchAll(/<tag ([^>]+?)\/>/g)].map(m=>{const b=attrib(m[1]);return[b.k,b.v];}));
   ways.set(a.id,{id:+a.id,refs,tags});
 }
 for(const match of xml.matchAll(/<relation\b([^>]*?)>([\s\S]*?)<\/relation>/g)){
   const a=attrib(match[1]); const members=[...match[2].matchAll(/<member ([^>]+?)\/>/g)].map(m=>attrib(m[1]));
   const tags=Object.fromEntries([...match[2].matchAll(/<tag ([^>]+?)\/>/g)].map(m=>{const b=attrib(m[1]);return[b.k,b.v];}));
   relations.set(a.id,{id:+a.id,members,tags});
 }
}
console.log('nodes',nodes.size,'ways',ways.size,'relations',relations.size);
const bounds = [56.254,22.125,56.435,22.392];
const origin = [56.3066,22.3320];
const toXY = ({lat,lon}) => [Math.round((lon-origin[1])*111319.49*Math.cos(origin[0]*Math.PI/180)*10)/10,Math.round((origin[0]-lat)*111319.49*10)/10];
const tagsOf=(way)=>way.tags;
const roads = [];
const buildings=[];
const water=[]; const areas=[]; const rails=[]; const points=[]; const lots=[]; const crossings=[];
const barriers = [], parks = [], streetFurniture = [], settlements = [], signals = [];
const pedestrianKinds = new Set(['path','footway','pedestrian','cycleway','steps']);
const wallMaterials = new Set(['stone', 'brick', 'concrete']);
const roadWidths={motorway:12,trunk:10,primary:8.8,secondary:7.4,tertiary:6.8,residential:5.7,unclassified:5.6,living_street:4.6,service:3.6,track:2.9,footway:1.8,pedestrian:3.2,cycleway:2,path:1.3,steps:1.5};
function roadWidth(tags){
 const real=parseFloat(tags.width);
 if(real>1&&real<40)return real;
 if(tags.lanes && Number(tags.lanes)>2) return Number(tags.lanes)*3.15+0.8;
 if(tags.oneway==='yes'&&tags.lanes==='1')return 3.9;
 return roadWidths[tags.highway] || 3.4;
}
for(const way of ways.values()){
 const tags=tagsOf(way);
 const coords=way.refs.map(id=>nodes.get(id));
 if(coords.some(p=>!p) || coords.length<2) continue;
 let xy=coords.map(toXY);
 const closed=way.refs[0]===way.refs.at(-1);
 if(closed) xy=xy.slice(0,-1);
 const level=parseInt(tags.layer||'0');
 if(tags.highway && !(tags.highway in {proposed:1,construction:1,platform:1,abandoned:1,corridor:1}) && (tags.area!=='yes')){
   const kind=tags.highway.replace(/_link$/,'');
   const asphalt=!(kind in {track:1,path:1,footway:1,steps:1,cycleway:1,pedestrian:1})&&!(tags.surface in {unpaved:1,grass:1,ground:1,gravel:1,dirt:1});
   const marked=asphalt&&['trunk','primary','secondary','tertiary'].includes(kind)&&tags.oneway!=='yes';
   const width=roadWidth({...tags,highway:kind});
   if(closed) xy.push(xy[0]);
   const row=[width,asphalt?1:0,marked?1:0,tags.name||'',xy];
   const surface = tags.surface || '';
   const style = pedestrianKinds.has(kind)
     ? ['paving_stones', 'sett', 'concrete:plates'].includes(surface) ? 'pavers'
       : ['asphalt', 'concrete', 'paved'].includes(surface) ? 'cycle' : 'trail'
     : asphalt ? '' : 'gravel';
   if (style || tags.bridge === 'yes' || tags.bridge === 'viaduct') {
     row.push({style, bridge: ['yes','viaduct'].includes(tags.bridge)});
   }
   if(level>=0) roads.push(row);
 }
 if(tags.building&&tags.building!=='no'&&closed&&xy.length>2){
   const levels=parseFloat(tags['building:levels']);
   const taggedHeight=parseFloat(tags.height);
   const b=tags.building;
   const footArea=Math.abs(xy.reduce((sum,p,index)=>{const q=xy[(index+1)%xy.length];return sum + p[0]*q[1]-q[0]*p[1];},0))*0.5;
   if(footArea<5) continue;
   const industrial=['warehouse','industrial','manufacture','garage','garages','service','train_station','shed','retail','supermarket'].includes(b);
   const commercial=['retail','commercial','supermarket','office'].includes(b)||!!tags.shop;
   const fitted=taggedHeight||(levels>0?levels*3.03+0.35: b==='apartments'?(footArea>300?14.6:10.8):industrial?(footArea>230?6.0:3.3):footArea>580?9.5:footArea>150?6.4:4.6);
   const profile=tags.amenity==='place_of_worship'||b==='church'?3:commercial?2:industrial?1:0;
   buildings.push([way.id,Math.round(fitted*10)/10,profile,xy,tags.name||'',footArea>45 && !industrial && !commercial && fitted < 8 ? 1 : 0]);
 }
 if (['fence', 'wall', 'retaining_wall', 'hedge'].includes(tags.barrier) && xy.length >= 2) {
    const type = tags.barrier === 'fence' ? (tags.fence_type === 'wood' ? 'wood' : 'metal') :
      tags.barrier === 'hedge' ? 'hedge' : tags.barrier === 'retaining_wall' ? 'retaining' : 'wall';
    const defaultHeight = {wood:1.25, metal:1.65, hedge:1.05, retaining:0.85, wall:1.1}[type];
    const height = Math.min(3.2, Math.max(0.35, parseFloat(tags.height) || defaultHeight));
    const ring = closed && !tags.highway && xy.length > 2 ? [...xy, xy[0]] : xy;
    const material = wallMaterials.has(tags.material) ? tags.material : '';
    if (!tags.building) barriers.push([type, height, ring, material]);
 }
 if (closed && xy.length > 2 && ['park', 'playground', 'garden'].includes(tags.leisure)) {
    parks.push([way.id, tags.name || '', tags.leisure, xy]);
 }
 if(closed&&xy.length>2&&tags.natural==='water')water.push(xy);
 if(closed&&xy.length>2&&tags.amenity==='parking'&&tags.parking!=='underground')lots.push(xy);
 if(closed&&xy.length>2&&(tags.leisure==='park'||tags.landuse==='forest'||tags.landuse==='cemetery'||tags.natural==='wood')){
    areas.push([tags.landuse==='forest'||tags.natural==='wood'?1:0,xy]);
 }
 if(tags.railway==='rail'&&level>=0)rails.push(xy);
}
function relationRings(relation){
 const pieces=relation.members.filter(m=>m.type==='way' && m.role==='outer').map(m=>ways.get(m.ref)?.refs).filter(Boolean).map(x=>x.slice());
 const rings=[];
 while(pieces.length){
   const ring=pieces.shift();
   while(ring[0]!==ring.at(-1)){
     const index=pieces.findIndex(piece=>piece[0]===ring.at(-1)||piece.at(-1)===ring.at(-1));
     if(index<0)break;
     const next=pieces.splice(index,1)[0];
     if(next.at(-1)===ring.at(-1))next.reverse();
     ring.push(...next.slice(1));
   }
   if(ring[0]===ring.at(-1)&&ring.length>3&&ring.every(id=>nodes.has(id)))rings.push(ring.slice(0,-1).map(id=>toXY(nodes.get(id))));
 }
 return rings;
}
for(const rel of relations.values()){
 if(rel.tags.natural==='water')water.push(...relationRings(rel));
 if(rel.tags.landuse==='forest'||rel.tags.natural==='wood'||rel.tags.leisure==='park')for(const ring of relationRings(rel))areas.push([rel.tags.landuse==='forest'||rel.tags.natural==='wood'?1:0,ring]);
}
for(const node of nodes.values()){
 if(node.tags.natural==='tree')points.push(toXY(node));
 if(node.tags.highway==='traffic_signals')signals.push(toXY(node));
 if(['Kruciai', 'Tirkšliai', 'Kalnėnai', 'Troškučiai', 'Tulnikiai', 'Griežė'].includes(node.tags.name) && node.tags.place) settlements.push([node.tags.name,toXY(node)]);
 if (['gate','lift_gate','swing_gate','kissing_gate'].includes(node.tags.barrier)) streetFurniture.push(['gate', toXY(node), 0]);
 const amenity = node.tags.amenity || node.tags.leisure;
 if (['bench','fountain','playground','waste_basket'].includes(amenity)) {
   streetFurniture.push([amenity, toXY(node), Number.parseFloat(node.tags.direction) || 0]);
 }
 if(node.tags.highway==='crossing' && !['unmarked','no'].includes(node.tags.crossing))crossings.push(toXY(node));
}
console.log({roads:roads.length,buildings:buildings.length,water:water.length,areas:areas.length,rails:rails.length,trees:points.length,lots:lots.length,crossings:crossings.length});
const source={attribution:"© OpenStreetMap contributors",license:"ODbL-1.0",source:"https://www.openstreetmap.org/copyright",bounds,origin,roads,buildings,water,areas,rails,trees:points,lots,crossings,settlements,signals};
const target = fileURLToPath(new URL('../data/city/mazeikiai.json', import.meta.url));
fs.mkdirSync(path.dirname(target),{recursive:true});
fs.writeFileSync(target,JSON.stringify(source));
const streetLayer = {barriers, parks, furniture: streetFurniture};
fs.writeFileSync(new URL("../data/city/street_details.json", import.meta.url), JSON.stringify(streetLayer));
console.log({barriers: barriers.length, parks: parks.length, furniture: streetFurniture.length});
