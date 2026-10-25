import { greet, add, quotient } from '@moonrockz/pubman-consumer';
import { initialize } from '@moonrockz/pubman-consumer/wasm';
function equal(a,b) { if (a !== b) throw new Error(`${a} != ${b}`); }
equal(greet('世界 🌙'),'Hello, 世界 🌙');
equal(add(20,22),42);
equal(quotient(1,0),-1);
const asset = new URL('/node_modules/@moonrockz/pubman-consumer/internal/wasm/library.wasm', location.href);
for (const options of [{}, {url:asset}, {bytes:await (await fetch(asset)).arrayBuffer()}]) {
  const api = await initialize(options);
  equal(api.greet('世界 🌙'),'Hello, 世界 🌙');
  equal(api.add(20,22),42);
  equal(api.quotient(12,3),4);
  equal(api.quotient(1,0),-1);
}
let rejected = false;
try { await initialize({url:new URL('/missing.wasm', location.href)}); } catch(e) { rejected = e.message.includes('Wasm-GC asset'); }
if (!rejected) throw new Error('missing asset diagnostic absent');
