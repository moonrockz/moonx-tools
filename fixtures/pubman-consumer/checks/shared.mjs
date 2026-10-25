import { greet, add } from '@moonrockz/pubman-consumer';
import { initialize } from '@moonrockz/pubman-consumer/wasm';

for (const api of [{ greet, add }, await initialize()]) {
  if (api.greet('shared 世界') !== 'Hello, shared 世界' || api.add(19, 23) !== 42) {
    throw new Error('portable Node/browser contract failed');
  }
}
