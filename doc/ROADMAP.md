# Versioned capability roadmap

This separates shipped history, the implementation in this checkout, and proposed
future work. Future version numbers are planning targets, not releases or working
APIs. No major-version removal or package publication is part of this change.

| Version | Status | Capability and documentation boundary |
| --- | --- | --- |
| 1.0.0 | Published, verified 2026-10-12 | Environment factories, aliases, fallback |
| 1.0.1 | Never published | Former documentation-only changelog entry folded into 2.0.0 |
| 2.0.0 | Implemented here; unreleased | Compatibility fixes, parsers, ordered providers, immutable values, typed binding/validation, native file/process adapters |
| 2.1.x | Proposed | Stable `Options<T>`, scoped `OptionsSnapshot<T>`, versioned snapshots, richer section binding and DI recipes |
| 2.2.x | Proposed | Validated atomic reload, file watches, filtered section monitors, last-known-good state, HTTP transport/polling, lifecycle and diagnostics |
| 2.3.x | Proposed | Optional Flutter asset and ValueListenable companion, mobile/web examples, opt-in presets |
| Future major | Optional; not scheduled | Deliberate removal of deprecated dynamic keys and nullable legacy futures, with migration guidance |

## Why 2.0.0 is the next release

The maintainer requested that the current work be committed as a new major
version. **2.0.0 supersedes the unpublished 1.1.0 plan** in the original
implementation specification; no intermediate 1.1.0 release is claimed.

This release implements the first stabilization/provider milestones. Providers
establish precedence, conversion, and failure rules for later typed options and
monitoring. Binding and validation are included now, while options/monitor APIs
remain future work. Existing environment registration and the Dart 3.0 minimum
remain supported; the version change does not require removing working APIs.

Each future implementation should add its own changelog entry when it is ready
and independently validated. Future minor version numbers above are proposals,
not commitments or published releases.

## Gates for later milestones

- Options: stable and scoped lifetimes must be distinct and tested. Models should
  be immutable; scope creation must be explicit in Dart.
- Monitoring: bind/validate before atomic publication; retain last-known-good on
  failure; debounce/coalesce; no events for equivalent values; cancel all owned
  watchers and subscriptions. Test atomic file replacement and optional creation.
- HTTP: injected transport, timeout and response-size limits, safe diagnostics,
  status/304 semantics, retry policy, and platform/CORS documentation.
- Flutter: separate SDK dependency, awaited asset initialization, immediate initial
  ValueListenable value, safe adapter disposal, and actual mobile/web compile tests.
- Version support: preserve the broadest SDK range that passes CI. Raise a minimum
  only for a demonstrated requirement, with a corresponding changelog entry.

SSE/WebSocket transports, hosted backends, and persistent encrypted caches remain
optional future integrations. Bundled assets, compiler defines, and process
variables must never be advertised as externally live-editable deployed sources.
