import { readFileSync, writeFileSync } from 'node:fs';

const directory = new URL('../assets/audio/sfx/', import.meta.url);
const rate = 24000;
const tau = Math.PI * 2;

function write(name, duration, sample) {
  const bytes = 2 * Math.round(duration * rate);
  const data = Buffer.alloc(44 + bytes);
  data.write('RIFF', 0);
  data.writeUInt32LE(data.length - 8, 4);
  data.write('WAVEfmt ', 8);
  data.writeUInt32LE(16, 16);
  data.writeUInt16LE(1, 20);
  data.writeUInt16LE(1, 22);
  data.writeUInt32LE(rate, 24);
  data.writeUInt32LE(rate * 2, 28);
  data.writeUInt16LE(2, 32);
  data.writeUInt16LE(16, 34);
  data.write('data', 36);
  data.writeUInt32LE(bytes, 40);
  for (let offset = 0; offset < bytes; offset += 2) {
    const value = Math.max(-1, Math.min(1, sample(offset / 2 / rate)));
    data.writeInt16LE(Math.round(value * 32767), 44 + offset);
  }
  writeFileSync(new URL(name, directory), data);
}

write('defeat.wav', 2.3, (t) => {
  const attack = Math.min(1, t * 55);
  const decay = Math.exp(-t * 2.1);
  const thud = Math.sin(tau * (43 * t + 5 * (1 - Math.exp(-9 * t)))) * decay;
  const resonant = [163, 212, 276].reduce((sum, hz, index) =>
    sum + Math.sin(tau * (hz * t - 20 * t * t)) * Math.exp(-t * (2.7 + index)),
  0);
  return attack * (thud * 0.52 + resonant * 0.12);
});

write('wanted_alert.wav', 0.68, (t) => {
  const pulse = t > 0.24 ? t - 0.24 : t;
  const envelope = Math.min(1, pulse * 130) * Math.exp(-pulse * 16);
  return 0.48 * envelope * (Math.sin(tau * (t > 0.24 ? 678 : 505) * pulse)
    + 0.27 * Math.sin(tau * 1040 * pulse));
});

const rand = ( index ) => {
  let code = Math.imul(index + 5709, 2246822519);
  code = Math.imul(code ^ (code >>> 13), 3266489917);
  return ((code ^ (code >>> 16)) >>> 0) / 2147483648 - 1;
};

write('gunshot.wav', 0.43, (t) => {
  const i = Math.floor(t * rate);
  const crack = (rand(i) - rand(i - 1) * 0.59) * Math.exp(-t * 61);
  const body = Math.sin(tau * (83 * t - 37 * t * t)) * Math.exp(-t * 21);
  const echo = t > 0.094 ? rand(i - 130) * Math.exp(-(t - 0.094) * 24) * 0.13 : 0;
  return (crack * 0.62 + body * 0.36 + echo) * Math.min(1, t * 430);
});

write('rain.wav', 5.0, (t) => {
  const i = Math.floor(t * rate);
  const noise = rand(i) * 0.19 + rand(Math.floor(i / 4)) * 0.074;
  const patter = rand(Math.floor(i / 23)) > 0.78 ? rand(i + 12) * 0.18 : 0;
  return (noise + patter) * Math.min(1, t * 15, (5.0 - t) * 15);
});

write('water_splash.wav', 0.64, (t) => {
  const i = Math.floor(t * rate);
  const pulse = Math.exp(-t * 9.1) * Math.min(t * 47, 1);
  return pulse * (rand(i) * 0.44 + rand(Math.floor(i / 6)) * 0.35 +
    Math.sin(tau * (170 - 131 * t) * t) * 0.11);
});

const audio = readFileSync(new URL('horn_hatchback.wav', directory));
let start = 12;
let fmt;
let clip;
while (start + 8 < audio.length) {
  const kind = audio.toString('ascii', start, start + 4);
  const length = audio.readUInt32LE(start + 4);
  const body = audio.subarray(start + 8, start + 8 + length);
  if (kind === 'fmt ') fmt = body;
  if (kind === 'data') clip = body;
  start += 8 + length + (length & 1);
}
if (fmt && clip && fmt.readUInt16LE(0) === 1 && fmt.readUInt16LE(14) === 16) {
  const tracks = fmt.readUInt16LE(2);
  const originalRate = fmt.readUInt32LE(4);
  const sample = (t) => {
    const frame = Math.floor(originalRate * t);
    const offset = frame * tracks * 2;
    if (offset < 0 || offset + tracks * 2 > clip.length) return 0;
    let sum = 0;
    for (let channel = 0; channel < tracks; channel++) sum += clip.readInt16LE(offset + channel * 2);
    return sum / (32768 * tracks);
  };
  for (const [variant, pitch, blend, pitchBase] of [
    ['sedan', 1.16, 0.20, 457],
    ['van', 0.76, 0.34, 220],
    ['police', 1.37, 0.27, 526],
  ]) {
    write('horn_' + variant + '.wav', 0.56, (time) => {
      const envelope = Math.min(time * 32, (0.56 - time) * 16, 1);
      const tone = Math.sin(tau * pitchBase * time) + 0.33 * Math.sin(tau * pitchBase * 1.55 * time);
      return envelope * (sample(time * pitch) * (1 - blend) + tone * blend);
    });
  }
}
