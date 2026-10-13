# Changelog

Versions are newest first. Dates record finalized release changes.

## 2.0.0 — 2026-10-12

### Major release

- Introduce configuration providers in version 2.0.0, superseding the earlier
  1.1.0 development plan.
- Preserve the existing environment API and Dart 3.0 SDK minimum. This major
  release does not remove legacy signatures or include the later monitoring,
  HTTP, or Flutter-adapter milestones.

### Configuration providers

- Add `EnvxBuilder`, `ConfigSource`, and immutable `MemoryConfigSource`.
- Add JSON-object and dotenv parsers with value-free syntax errors.
- Add native JSON/dotenv file providers and process environment variables through
  `package:envx/envx_io.dart`, with prefix filtering and nested-key mapping.
- Merge objects recursively in source order; later lists, scalars, and explicit
  null replace earlier values. Preserve case-sensitive keys and input immutability.
- Add `ConfigValues` primitive/section access, escaped paths, typed model binding,
  validation, and typed exceptions. Concurrent builds share source loading;
  subsequent builds reload sources explicitly.
- Optional files skip absence only; unreadable, malformed, and invalid content fails.

### Compatibility and reliability (planned 1.0.x fixes included here)

- Resolve the default `APP_ENV` through a fixed const declaration and accept an
  application-supplied `environment` for reliable custom compiler keys.
- Deprecate the `defineKey` parameter; retain its custom dynamic fallback solely
  for 1.x compatibility. Document its AOT limitations and migration path.
- Add opt-in per-instance factory caching, in-flight deduplication, retry after
  failure, and explicit `clearCache()`.
- Add opt-in strict environment selection and resolver collision checks.
- Preserve legacy nullable futures, default fallback, and uncached factory behavior.

### Documentation and quality

- Expand the README into a use-case guide with a contents index, API behavior
  tables, environment selection, typed models, custom sources, Flutter startup,
  caching, test overrides, and troubleshooting recipes.
- Make the main package example self-contained; add an exact runnable quick
  start and native production/dotenv fixtures. Reference the main example in
  pubspec metadata and document pub.dev's conventional example discovery.

- Add runnable provider and compiler-selection examples, migration and provider
  guides, documented pubspec metadata, and a capability/version roadmap.
- Add format, analysis, test, AOT/JavaScript compile, publish dry-run, and PANA CI.
- Correct docs deployment to `main` and use a standalone Dart SDK.
- Correct the former 1.0.1 changelog claim: no 1.0.1 release was published; its
  documentation work is included in 2.0.0. A 160/160 score is a validation target,
  not a claim about an unmeasured published release.

## 1.0.0

- Initial generic environment registration, async factories, aliases, and tokens.
