## Context

`report` in `apps/zig-cross/doctor.mbt` builds every finding. The `ZC_TOOLCHAIN_UNVERIFIED` finding already gets all requested target names (`names`). Other command steps use the `<package-path>` placeholder, which the README tells readers to replace. `zig-cross build` accepts many targets, including `host`, before `--`.

## Goals / Non-Goals

**Goals:**
- A validation command that a consumer can run after the placeholder is replaced.
- Code, README and spec that agree on the finding severities.

**Non-Goals:**
- No new finding codes, fields, severities or statuses, and no schema version change.
- No change to other findings or to build and exec.

## Decisions

- **One build command for all affected targets.** Use `zig-cross build <targets> -- <package-path>` with the finding's targets in report order. One command per target was the alternative; it gives more steps and no more information, because `build` reports each target result.
- **Keep the severity `unverified` and document it.** 0.3.0 is published with `"severity": "unverified"`, and schema version 1 permits only additive changes. Changing the value to `unknown`, the status name, would break consumers that match on it. The README and the spec now list the severities `error`, `warning` and `unverified` and the existing status mapping.
- **State the runtime in the prerequisites.** In sync mode an unassessed toolchain refuses execution (`ZC_SYNC_UNAVAILABLE`), so the command runs only with the full runtime. The prerequisites say so. The fixture name is not useful to consumers, so the prerequisites do not mention it.

## Risks / Trade-offs

- [A consumer parses the old command text] → The command text is prose-like guidance; the README tells agents to consume codes and statuses. The code and the severity stay the same.
