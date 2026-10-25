export interface API {
  greet(name: string): string;
  add(a: number, b: number): number;
  quotient(a: number, b: number): number;
}
export interface InitOptions {
  bytes?: BufferSource;
  url?: string | URL;
  imports?: WebAssembly.Imports;
}
export function initialize(options?: InitOptions): Promise<API>;
