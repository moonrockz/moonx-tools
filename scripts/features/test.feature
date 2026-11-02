Feature: Host limits of workspace test suites
  Scenario: Windows skips only suites that need a POSIX host
    Then on "Windows_NT", "apps/pubman" for "wasm" is skipped
    And on "Windows_NT", "apps/pubman" for "native" is skipped
    And on "Windows_NT", "apps/zig-cross" for "native" is skipped
    And on "Windows_NT", "apps/zig-cross" for "wasm" runs
    And on "Windows_NT", "fixtures/consumer" for "native" runs
    And on "Windows_NT", "fixtures/pubman-consumer" for "native" runs

  Scenario: Linux and macOS keep every suite
    Then on "Linux", "apps/pubman" for "wasm" runs
    And on "Linux", "apps/zig-cross" for "native" runs
    And on "Darwin", "apps/pubman" for "native" runs
    And on "Darwin", "apps/zig-cross" for "native" runs
