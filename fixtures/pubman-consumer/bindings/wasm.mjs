import { instantiate } from '../internal/wasm/loader.mjs';
export async function initialize(options = {}) {
  const api = await instantiate(options);
  return { greet: name => api.greet(name), add: (a,b) => api.add(a,b), quotient: (a,b) => api.quotient(a,b) };
}
