import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [, , source, destination, decoderPath] = process.argv;
if (!source || !destination || !decoderPath) {
  throw new Error('Usage: node tools/prepare_vehicle_glb.mjs source.glb output.glb path-to-meshopt_decoder.module.js');
}

const { MeshoptDecoder } = await import(pathToFileURL(path.resolve(decoderPath)));
await MeshoptDecoder.ready;
const file = fs.readFileSync(source);
if (file.toString('ascii', 0, 4) !== 'glTF' || file.readUInt32LE(4) !== 2) throw new Error('A glTF 2.0 binary is required.');
const jsonSize = file.readUInt32LE(12);
const document = JSON.parse(file.subarray(20, 20 + jsonSize));
const bin = file.subarray(28 + jsonSize);
const output = [];
let byteLength = 0;
function addChunk(chunk) {
  const offset = byteLength;
  const padding = (4 - chunk.length % 4) % 4;
  output.push(chunk, Buffer.alloc(padding));
  byteLength += chunk.length + padding;
  return offset;
}
const decoded = document.bufferViews.map(view => {
  const compressed = view.extensions?.EXT_meshopt_compression;
  const bytes = compressed
    ? Buffer.alloc(compressed.count * compressed.byteStride)
    : bin.subarray(view.byteOffset ?? 0, (view.byteOffset ?? 0) + view.byteLength);
  if (compressed) {
    const start = compressed.byteOffset ?? 0;
    MeshoptDecoder.decodeGltfBuffer(bytes, compressed.count, compressed.byteStride,
      bin.subarray(start, start + compressed.byteLength), compressed.mode, compressed.filter);
  }
  view.buffer = 0;
  view.byteOffset = addChunk(bytes);
  view.byteLength = bytes.length;
  delete view.extensions;
  return bytes;
});
const types = {5120: [1, 'readInt8', 127], 5121: [1, 'readUInt8', 255],
  5122: [2, 'readInt16LE', 32767], 5123: [2, 'readUInt16LE', 65535]};
const sizes = {SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4};
const quantized = new Set();
for (const mesh of document.meshes) {
  for (const primitive of mesh.primitives) {
    for (const accessor of Object.values(primitive.attributes)) quantized.add(accessor);
  }
}
for (const id of quantized) {
  const accessor = document.accessors[id];
  if (!types[accessor.componentType]) continue;
  const [componentSize, read, maximum] = types[accessor.componentType];
  const dimensions = sizes[accessor.type];
  const view = document.bufferViews[accessor.bufferView];
  const stride = view.byteStride || dimensions * componentSize;
  const bytes = decoded[accessor.bufferView];
  const floats = Buffer.alloc(accessor.count * dimensions * 4);
  for (let item = 0; item < accessor.count; item++) {
    for (let component = 0; component < dimensions; component++) {
      const value = bytes[read]((accessor.byteOffset ?? 0) + item * stride + component * componentSize);
      floats.writeFloatLE(accessor.normalized ? Math.max(-1, value / maximum) : value, (item * dimensions + component) * 4);
    }
  }
  if (accessor.normalized) {
    for (const limit of ['min', 'max']) {
      if (accessor[limit]) accessor[limit] = accessor[limit].map(v => Math.max(-1, v / maximum));
    }
  }
  accessor.bufferView = document.bufferViews.length;
  accessor.byteOffset = 0;
  accessor.componentType = 5126;
  delete accessor.normalized;
  document.bufferViews.push({ buffer: 0, byteOffset: addChunk(floats), byteLength: floats.length, target: 34962 });
}
for (const material of document.materials) {
  if (material.pbrMetallicRoughness) {
    delete material.pbrMetallicRoughness.baseColorTexture;
    delete material.pbrMetallicRoughness.metallicRoughnessTexture;
  }
  for (const key of ['normalTexture', 'occlusionTexture', 'emissiveTexture']) delete material[key];
  delete material.extensions;
}
delete document.images;
delete document.textures;
delete document.samplers;
delete document.extensionsUsed;
delete document.extensionsRequired;
document.buffers = [{ byteLength }];
const json = Buffer.from(JSON.stringify(document));
const padded = Buffer.concat([json, Buffer.alloc((4 - json.length % 4) % 4, 32)]);
const header = Buffer.alloc(20);
header.write('glTF');
header.writeUInt32LE(2, 4);
header.writeUInt32LE(28 + padded.length + byteLength, 8);
header.writeUInt32LE(padded.length, 12);
header.write('JSON', 16);
const binaryHeader = Buffer.alloc(8);
binaryHeader.writeUInt32LE(byteLength);
binaryHeader.write('BIN\0', 4);
fs.writeFileSync(destination, Buffer.concat([header, padded, binaryHeader, ...output]));

