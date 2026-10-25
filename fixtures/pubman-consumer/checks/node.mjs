import assert from 'node:assert/strict';
import { readFile, rename } from 'node:fs/promises';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
const entry = fileURLToPath(import.meta.resolve('@moonrockz/pubman-consumer'));
const asset = resolve(dirname(entry), '../internal/wasm/library.wasm');
// The root entry must work even when the Wasm asset cannot be opened.
await rename(asset, asset + '.hidden');
try {
  const js = await import('@moonrockz/pubman-consumer');
  assert.equal(js.greet('世界 🌙'), 'Hello, 世界 🌙');
  assert.equal(js.add(20,22), 42);
  assert.equal(js.quotient(3,0), -1);
} finally { await rename(asset + '.hidden', asset); }
const { initialize } = await import('@moonrockz/pubman-consumer/wasm');
for (const options of [{}, {bytes: await readFile(asset)}, {url: pathToFileURL(asset)}]) {
  const api = await initialize(options);
  assert.equal(api.greet('世界 🌙'), 'Hello, 世界 🌙');
  assert.equal(api.add(20,22),42);
  assert.equal(api.quotient(3,0),-1);
  assert.equal(api.quotient(12,3),4);
}
await assert.rejects(initialize({url: pathToFileURL(asset + '.missing')}), /Wasm-GC asset/);
// A valid Wasm module with a required missing host import exercises diagnostics.
const missingImport = Uint8Array.from([0,97,115,109,1,0,0,0,1,4,1,96,0,0,2,7,1,1,109,1,102,0,0]);
await assert.rejects(initialize({bytes:missingImport}), /host imports/);
await initialize({bytes:missingImport, imports:{m:{f(){}}}});
// An invalid binary/runtime capability failure must remain actionable.
await assert.rejects(initialize({bytes:new Uint8Array([0])}), /Requires Wasm-GC/);

const originalInstantiate = WebAssembly.instantiate;
try {
  WebAssembly.instantiate = async () => { throw new Error('Wasm-GC unsupported by host'); };
  await assert.rejects(initialize({bytes:await readFile(asset)}), /Requires Wasm-GC/);
} finally { WebAssembly.instantiate = originalInstantiate; }
