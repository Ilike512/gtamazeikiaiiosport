import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const project = fileURLToPath(new URL("../", import.meta.url));
const sampleRate = 16000;
const tau = 2 * Math.PI;

function writeWave(relative, duration, sample) {
  const numberOfSamples = Math.floor(duration * sampleRate);
  const out = Buffer.alloc(44 + numberOfSamples * 2);
  out.write("RIFF", 0);
  out.writeUInt32LE(out.length - 8, 4);
  out.write("WAVEfmt ", 8);
  out.writeUInt32LE(16, 16);
  out.writeUInt16LE(1, 20);
  out.writeUInt16LE(1, 22);
  out.writeUInt32LE(sampleRate, 24);
  out.writeUInt32LE(sampleRate * 2, 28);
  out.writeUInt16LE(2, 32);
  out.writeUInt16LE(16, 34);
  out.write("data", 36);
  out.writeUInt32LE(out.length - 44, 40);
  for (let index = 0; index < numberOfSamples; index++) {
    const time = index / sampleRate;
    out.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sample(time, index))) * 32767), 44 + index * 2);
  }
  const path = resolve(project, relative);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, out);
}

function sine(hz, time) {
  return Math.sin(tau * hz * time);
}

function noise(index) {
  const hashed = Math.imul(index ^ (index >>> 5), 0x45d9f3b);
  return ((hashed ^ (hashed >>> 16)) & 65535) / 32768 - 1;
}

writeWave("assets/audio/sfx/engine.wav", 1, (time) =>
  .28 * sine(45, time) * (.78 + .22 * sine(15, time)) +
  .10 * sine(90, time) + .034 * sine(165, time));
writeWave("assets/audio/sfx/door.wav", .19, (time, index) =>
  (.4 * sine(76, time) + .55 * noise(index)) * Math.exp(-32 * time));
writeWave("assets/audio/sfx/impact.wav", .39, (time, index) =>
  .39 * sine(53, time) * Math.exp(-17 * time) +
  .48 * noise(index) * Math.exp(-24 * time) +
  .16 * sine(497, time) * Math.exp(-29 * time));

for (const [name, gain, frequency, decay] of [
  ['footstep_walk', .48, 97, 25], ['footstep_run', .72, 73, 19]
]) {
  writeWave("assets/audio/sfx/" + name + ".wav", .19, (time, index) => {
    const heel = sine(frequency * (1 - time * 3), time) * Math.exp(-decay * time);
    const toe = Math.max(0, time - .048);
    const scuff = time > .048 ? (noise(index) - .53 * noise(index - 1)) * Math.exp(-64 * toe) : 0;
    return Math.min(1, time * 380) * gain * (.30 * heel + .19 * scuff + .14 * noise(index) * Math.exp(-69 * time));
  });
}
writeWave("assets/audio/sfx/birdsong.wav", 1.48, (time) => {
  const calls = [[.02,2320,510,.15], [.22,3030,-760,.13], [.50,2640,390,.21], [.85,3240,-1030,.28], [1.22,2320,630,.11]];
  return calls.reduce((mix, [start, hz, sweep, length]) => {
    const t = time - start;
    if (t < 0 || t >= length) return mix;
    const phase = hz * t + sweep * t * t / length;
    const envelope = Math.sin(Math.PI * t / length) ** 1.6;
    return mix + envelope * (Math.sin(tau * phase) + .13 * Math.sin(tau * 1.9 * phase)) * .24;
  }, 0);
});
writeWave("assets/audio/sfx/police_siren.wav", 2.4, (time) => {
  const modulation = 1 / 2.4;
  const phase = 780 * time - 145 * Math.sin(tau * modulation * time) / (tau * modulation);
  return .21 * (Math.sin(tau * phase) + .25 * Math.sin(2 * tau * phase));
});
