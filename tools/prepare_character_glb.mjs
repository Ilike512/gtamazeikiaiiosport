import fs from 'node:fs';

const [, , source, target] = process.argv;
if (!source || !target) throw new Error('Pass the source GLB and the project destination.');
const data = fs.readFileSync(source);
if (data.toString('ascii', 0, 4) !== 'glTF' || data.readUInt32LE(4) !== 2) {
  throw new Error('Expected a binary glTF 2.0 character.');
}
const jsonLength = data.readUInt32LE(12);
const model = JSON.parse(data.subarray(20, 20 + jsonLength));
if (!model.skins?.length || !model.animations?.length) {
  throw new Error('The model needs a skin and animation clips.');
}

const bones = {
  Hips: 'hips', Spine: 'spine', Spine1: 'spine_middle', Spine2: 'chest', Neck: 'neck', Head: 'head',
};
for (const side of ['Left', 'Right']) {
  const suffix = side[0];
  for (const [original, name] of Object.entries({
    Arm: 'upperarm', ForeArm: 'forearm', Hand: 'hand', UpLeg: 'thigh',
    Leg: 'calf', Foot: 'foot', ToeBase: 'toe',
  })) {
    bones[side + original] = name + '_' + suffix;
  }
}
for (const node of model.nodes) {
  const name = node.name?.replace(/^mixamorig[:_]?/i, '');
  if (bones[name]) node.name = bones[name];
}

const names = {
  'Idle': 'idle', 'Walk': 'walk', 'Run': 'run', 'Jump': 'leap', 'Jump start': 'leap',
  'Jump takeoff': 'leap', 'Jump take-off': 'leap', 'Jump land': 'land', 'Vault over obstacle': 'vault', 'Swim forward (front crawl)': 'swim',
  'Swim breaststroke': 'swim_dive', 'Tread water': 'tread', 'Dive into water': 'swim_enter',
  'Climb out of water': 'swim_exit', 'Wave': 'wave', 'Punch': 'punch', 'Pistol fire': 'fire',
  'Rifle fire (single)': 'rifle_fire', 'Board convertible (driver)': 'car_entry',
  'Pick up (ground)': 'search_car', 'Side throw (right hand)': 'throw_item',
  'Get up (from back)': 'get_up', 'Slouch walk': 'walk_slouch',
};
const imported = new Set();
for (const clip of model.animations) {
  clip.name = names[clip.name] ?? clip.name;
  imported.add(clip.name);
}
for (const required of ['idle', 'walk', 'run']) {
  if (!imported.has(required)) throw new Error('Missing animation ' + required);
}

const json = Buffer.from(JSON.stringify(model));
const withPadding = Buffer.concat([json, Buffer.alloc((4 - json.length % 4) % 4, 32)]);
const header = Buffer.from(data.subarray(0, 20));
const bin = data.subarray(20 + jsonLength);
header.writeUInt32LE(20 + withPadding.length + bin.length, 8);
header.writeUInt32LE(withPadding.length, 12);
fs.writeFileSync(target, Buffer.concat([header, withPadding, bin]));

