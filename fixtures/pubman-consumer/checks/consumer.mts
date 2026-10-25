import { greet, add, quotient } from '@moonrockz/pubman-consumer';
import { initialize, type API } from '@moonrockz/pubman-consumer/wasm';
const text: string = greet('world');
const n: number = add(1,2) + quotient(12,3);
const api: API = await initialize();
const other: string = api.greet(text);
const number: number = api.add(n,2);
// @ts-expect-error numeric input must not weaken to any
greet(42);
// @ts-expect-error numeric arguments only
add('one',2);
// @ts-expect-error numeric arguments only
quotient('one',2);
// @ts-expect-error Wasm string input only
api.greet(42);
// @ts-expect-error Wasm numeric arguments only
api.add('one',2);
// @ts-expect-error Wasm numeric arguments only
api.quotient('one',2);
// @ts-expect-error initializer options must have the declared shape
initialize({bytes:'wrong'});
void other; void number;
