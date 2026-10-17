# Consumer fixture

Small MoonBit package exercised by `mise run test:consumer` and CI.

`moon run apps/zig-cross --target wasm -- build <target> -- fixtures/consumer`
cross-builds this package, checks the executable header, and `exec host`
runs its native tests.
