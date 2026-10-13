# envx — Unified Engineering Roadmap & Codex Work Implementation Specification

**Status:** Proposed future work; not yet implemented  
**Prepared:** 2026-10-12  
**Repository:** https://github.com/arlamend7/dart_envx  
**Published package:** https://pub.dev/packages/envx  
**Baseline reviewed:** `main` branch, `pubspec.yaml` version `1.0.0` at review time  
**Primary audience:** Codex Work / coding agents and maintainers  
**Scope:** Combine the environment-resolution code review, .NET/Angular-inspired configuration providers, runtime configuration, monitoring, typed options, Flutter integrations, documentation, testing, and release strategy into a single actionable specification.

> **For Codex Work:** Treat this file as the implementation brief. Inspect the latest repository and package state before editing because the baseline may have changed. Follow the compatibility and acceptance criteria. Implement in small, testable phases; do not assume code examples in this document already exist. The examples illustrate the **target design**, not the current public API. Do not publish packages, push tags, or make breaking releases without an explicit authorization.

---

## 1. Executive summary

Evolve `envx` from a lightweight compile-time environment selector into an **extensible, strongly typed configuration-management library for Dart and Flutter**, inspired by:

- **.NET configuration providers:** ordered sources, `appsettings.json` conventions, environment overrides, section binding, validation, and options-pattern dependency injection.
- **.NET options:** stable `Options<T>`, scope-specific `OptionsSnapshot<T>`, and dynamically updated `OptionsMonitor<T>` with change notifications.
- **Angular runtime initialization:** load remote configuration asynchronously **before** services/widgets depend on it; allow separately deployed runtime configuration where the platform permits it.
- **Idiomatic Dart/Flutter:** `Future`, `Stream`, immutable models, constructor injection, and optional `ValueListenable<T>` adapters. Avoid mandatory global state, service locators, or dependency-injection frameworks.

The intended value proposition is not merely another `.env` parser. It is the full lifecycle:

**select environment → load providers → merge in order → bind typed model → validate → atomically publish snapshot → monitor sources → reload → notify consumers.**

### Primary outcomes

1. Preserve existing `Environment.register()` users until an intentional major-version migration.
2. Fix or retire the unreliable dynamic use of compile-time environment declarations.
3. Add file, memory, platform environment, HTTP, and Flutter-asset configuration sources where supported.
4. Define deterministic precedence, nested merge, missing-source, and error rules.
5. Support both typed configuration and convenient key/section access.
6. Provide reusable monitoring, explicit reload, atomic snapshots, and DI-friendly options interfaces.
7. Make features opt-in, platform-safe, testable, and documented; avoid forcing Flutter or heavyweight network dependencies on plain Dart users.

### Non-goals for the first iterations

- Managing operating-system environment variables or mutating another process's environment.
- Hot-reloading values embedded in `--dart-define` or compiled Flutter assets in production.
- Shipping application secrets securely to an untrusted Flutter/web client.
- Implementing a hosted feature-flag or secrets-management backend.
- Imposing Riverpod, Bloc, GetIt, Provider, or any one DI system.
- Attempting to match every feature of ASP.NET Core's configuration stack immediately.

---

## 2. Verified baseline and existing API

The repository reviewed contains:

| File | Current responsibility |
|---|---|
| `lib/envx.dart` | `Environment.register`, `EnvironmentInstance<K,C>` public API. |
| `lib/src/environment_registry.dart` | Environment-key-to-async-factory map; default fallback. |
| `lib/src/environment_service.dart` | Resolves environment keys, including attempted `String.fromEnvironment` lookup. |
| `lib/src/default_resolvers.dart` | Enum alias/token resolvers. |
| `lib/src/types.dart` | Resolver type alias and `APP_ENV` constant. |
| `example/envx_example.dart` | Development/production factories. |
| `test/envx_test.dart` | Basic resolution, fallback, String environment, and missing resolver tests. |
| `.github/workflows/publish.yml` | Publishing on tags. |
| `.github/workflows/deploy-docs.yml` | Documentation deployment. |

Current usage resembles:

```dart
final env = Environment.register(
  configuration: {
    AppEnvironment.development: () async => DevelopmentConfig(),
    AppEnvironment.production: () async => ProductionConfig(),
  },
  resolver: parseEnvironment,
  defaultEnvironment: AppEnvironment.development,
);
final config = await env.current();
```

**Preserve:** generics, custom resolvers, alias support, asynchronous factories, and multiple independent instances. The library currently has no mandatory global singleton; keep that principle for the new system.

### 2.1 Baseline issues requiring attention

| ID | Severity | Observation | Required resolution |
|---|---|---|---|
| B-01 | Critical | `resolveFromBuildDefine()` calls `String.fromEnvironment(k, defaultValue: defineKey)` using a runtime variable for `k`. Such lookups are only guaranteed in const contexts; the fallback is the variable *name* (`APP_ENV`), not the desired environment. | Read named compile-time definitions at a **const call site in application code**, pass the resulting value to the library, and document/deprecate misleading dynamic-define behavior. Keep a compatible migration path. |
| B-02 | High | `EnvironmentRegistry.tryGet()` invokes the async factory on every lookup. | Add optional per-instance caching/in-flight request deduplication, or use immutable snapshots in the new manager. Make refresh explicit. |
| B-03 | High | A missing configuration can return `null` and silently fall back to the default environment. | Support strict/fail-fast mode, detailed errors, required sources, and explicit `try*` methods. Preserve existing legacy behavior unless a breaking release is authorized. |
| B-04 | Medium | `Future<C>? current()` / `getEnvironment*()` makes nullable futures part of the API. | In the **new** API use `Future<C>` for required values and `Future<C?>` for optional reads. Migrate the legacy API only in a major release. |
| B-05 | Medium | Alias collisions in resolver construction silently overwrite previous mappings. | Detect collisions and either reject them or expose strict collision validation; retain old semantics until migration if needed. |
| B-06 | Medium | Comments/documentation do not always clearly distinguish missing lookup vs default fallback vs factory failure. | Document each case and add tests; do not silently swallow thrown factory exceptions. |
| B-07 | Medium | Docs workflow listens to `master`, but repository default is `main`. | Update `.github/workflows/deploy-docs.yml` to `main` and verify deployment permissions. |
| B-08 | Medium | `CHANGELOG.md` contains an entry for `1.0.1` while `pubspec.yaml` indicates `1.0.0` in reviewed baseline. | Reconcile published version history and changelog. Do not assume an unpublished release exists. |
| B-09 | Medium | No dedicated CI validation workflow was observed; tests cover a small subset of behavior. | Add format, analyze, test, package validation, and platform-specific tests. |
| B-10 | Low | Example uses a top-level mutable `environment` variable, despite the library's no-global-state positioning. | Prefer passing configuration to app/services via constructors in examples. |

### 2.2 Correct compile-time selection pattern

```dart
// Application code — const declaration, not dynamic lookup inside a library.
const selectedEnvironment = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'development',
);

// Current API can already resolve an explicit string:
final config = await env.getEnvironment(selectedEnvironment);
```

A library cannot reliably read an **arbitrarily named** compiler environment key selected only at runtime. If supporting convenience methods for known compile-time keys, use fixed const expressions; preferably accept a previously resolved `environment` string. `Platform.environment` is **not** equivalent to `String.fromEnvironment`.

---

## 3. Target system architecture

```text
Application startup
       |
       v
Select environment (explicit argument / const build define / native OS setting)
       |
       v
EnvxBuilder: ordered ConfigSource instances
       |
       +--> In-memory defaults
       +--> General JSON / .env files
       +--> Environment-specific files
       +--> Remote HTTP JSON
       +--> OS process environment variables
       +--> Explicit overrides
       |
       v
Load all required/available providers (async)
       |
       v
Normalize keys + recursively merge (last provider wins)
       |
       v
Bind typed model + validate
       |
       v
Atomically publish immutable ConfigurationSnapshot(version, values, model)
       |
       +--> Options<T> (stable value)
       +--> OptionsSnapshot<T> (scope-bound value)
       +--> OptionsMonitor<T> (current + change stream)
       +--> Section monitors
       |
       v
Application services / Flutter widgets

Watchable sources (file events / HTTP poll / in-memory events)
       |
       v
Debounce + coalesce + reload all providers + validate
       |
       +--> failure: retain last-known-good snapshot; emit diagnostics
       +--> unchanged effective config: no value-change event
       +--> changed: atomically swap and notify monitors
```

### Architectural components

1. **Environment selection** (`EnvironmentResolver<K>`): maps `dev`/`prod`/aliases to an environment identifier; independent from configuration value loading.
2. **Config sources**: provider interface with `load()`. Some implementations also expose a change/invalidation stream.
3. **Config manager**: orchestrates loading, precedence, merging, binding, validation, caching, monitoring, and lifecycle.
4. **Configuration snapshot**: immutable, versioned final configuration; no partially updated values.
5. **Options abstractions**: injectable read-only contracts around the snapshot/current validated model.
6. **Platform adapters**: IO filesystem/OS environment; Flutter assets; HTTP transport. Avoid unconditional `dart:io` in web entry points.
7. **Diagnostics**: typed exceptions, reload status, provider provenance, optional redacted logging.

### Design rules

- No mandatory global `Environment.instance` or static mutable registry.
- Dependencies are injected through constructors; DI framework bindings are optional examples/adapters.
- Watching is opt-in; ordinary reads never repeatedly hit the network/disk.
- All published configuration must have passed binding and validation.
- A source's change event means **invalidate and reload**, not automatically accept its raw values.
- Remote HTTP settings contain **data only**, never executable Dart code.
- Do not mix platform-specific imports into the core library's web-compatible public surface.

---

## 4. Proposed API contracts

All interfaces, method names, and examples in this section are **design targets**. Codex should refine signatures using actual Dart compile checks, not treat them as already present. Preserve coherent naming across packages.

### 4.1 Core source and monitor interfaces

```dart
abstract interface class ConfigSource {
  Future<Map<String, Object?>> load();
}

abstract interface class WatchableConfigSource implements ConfigSource {
  // Emits invalidation signals, not raw secrets/config values.
  Stream<void> get changes;
}

abstract interface class Options<T> {
  T get value;                 // Stable for this options instance.
}

abstract interface class OptionsSnapshot<T> {
  T get value;                 // Fixed for one operation/request scope.
}

abstract interface class OptionsMonitor<T> {
  T get currentValue;         // Latest successfully validated value.
  Stream<ConfigChange<T>> get changes;
  Future<void> reload();      // Explicit refresh; serialized/coalesced.
}

class ConfigChange<T> {
  const ConfigChange({
    required this.previousValue,
    required this.currentValue,
    required this.version,
    required this.timestamp,
  });

  final T previousValue;
  final T currentValue;
  final int version;
  final DateTime timestamp;
}
```

Define monitor lifetime/cleanup (`dispose()` or `close()`), error/status observability, and immutability guarantees in the concrete manager. Keep consumers' `OptionsMonitor<T>` surface minimal; do not force every injected consumer to gain privileges to dispose a shared manager.

**Options semantics** (model after .NET, adapted to Dart):

| Contract | Semantics | Typical lifetime |
|---|---|---|
| `Options<T>` | Captured stable settings; does not track later changes. | Singleton/configuration registration |
| `OptionsSnapshot<T>` | Captures settings when a scope begins; remains stable during that scope. | HTTP request, job, UI transaction |
| `OptionsMonitor<T>` | Current latest validated settings; changes stream. | Singleton shared manager |

In Dart there is no built-in request-scoped DI container: snapshots must be explicitly obtained and registered at each application's scope boundary.

### 4.2 Builder and instance contracts

Proposed ergonomic design:

```dart
// Basic load: return one validated typed model.
final config = await EnvxBuilder()
    .addMemory({'api': {'timeoutSeconds': 30}})
    .addJsonFile('config/appsettings.json')
    .addJsonFile('config/appsettings.$appEnv.json', optional: true)
    .build<AppConfig>(AppConfig.fromJson);

// Monitored load: await initialization; return manager/monitor.
final settings = await EnvxBuilder()
    .addJsonFile('config/appsettings.json', reloadOnChange: true)
    .addHttpJson(
      Uri.parse('https://config.example.com/app.json'),
      refreshInterval: const Duration(minutes: 5),
      optional: true,
    )
    .buildMonitor<AppConfig>(
      AppConfig.fromJson,
      validate: validateAppConfig,
    );

final initialUrl = settings.currentValue.api.baseUrl;
final subscription = settings.changes.listen((change) {
  print('Configuration version: ${change.version}');
});

await settings.reload();
await subscription.cancel();
await settings.dispose();
```

Prefer builder methods as convenience extensions defined by adapters (`envx_io`, `envx_http`, `envx_flutter`) rather than loading all platform dependencies through `envx.dart`. If `EnvxBuilder` offers a plain `addSource(ConfigSource source)` method, users can add arbitrary custom providers without waiting for a first-party package.

**Initial-load rule:** `buildMonitor` must not return a usable monitor until required sources finish loading and the model is validated. After this, `currentValue` is synchronous and safe to read.

**Required vs optional:** `optional: true` means a missing/unreachable source may be skipped *under the documented failure policy*. It must not erase previously validated values, and it must not hide schema/validation failures by default. Distinguish not-found, timeout, parse failure, unauthorized, and application-invalid cases.

### 4.3 Strongly typed models and untyped access

```dart
class ApiSettings {
  const ApiSettings({required this.baseUrl, required this.timeoutSeconds});
  final String baseUrl;
  final int timeoutSeconds;

  factory ApiSettings.fromJson(Map<String, Object?> json) {
    return ApiSettings(
      baseUrl: json['baseUrl'] as String,
      timeoutSeconds: json['timeoutSeconds'] as int,
    );
  }
}
```

Also expose low-friction raw value access (e.g. `config.getString('api.baseUrl')`, `getInt`, `getBool`, `getSection`) with clear path semantics and descriptive missing/type-conversion errors. Do not require a code-generation dependency; generated serializers (`json_serializable`, `freezed`, etc.) can work through callers' binder functions.

### 4.4 Section monitoring

Proposed:

```dart
final apiOptions = settings.monitorSection<ApiSettings>(
  'api',
  ApiSettings.fromJson,
);

class ApiService {
  ApiService(this._settings);
  final OptionsMonitor<ApiSettings> _settings;

  Future<void> fetch() async {
    final baseUrl = _settings.currentValue.baseUrl;
    // Use current URL for this operation.
  }
}
```

The monitor should emit when the **effective selected section** changes, not whenever an unrelated configuration key changes. Support equality/fingerprints for models that do not implement meaningful `==`; ensure registration-time and reload-time binder/validator errors have explicit behavior. Prefer validating registered sections **before** publishing a new global snapshot, or document and isolate failure behavior consistently.

### 4.5 Dependency injection: no framework lock-in

```dart
class AuthService {
  AuthService(this.settings);
  final OptionsMonitor<AuthSettings> settings;

  String get authority => settings.currentValue.authority;
}

final authService = AuthService(authOptions);
```

Document how to register a single manager as a singleton and provide typed/section monitors. Include sample wiring with GetIt or Riverpod as optional integrations, not core dependencies.

---

## 5. Provider catalog and platform strategy

| Provider | Input | Dart VM/server | Flutter mobile/desktop | Flutter web | Monitoring |
|---|---|---|---|---|---|
| In-memory | `Map<String,Object?>` | Yes | Yes | Yes | Explicit updates |
| JSON **filesystem** | File path | Yes | Only accessible filesystem paths | No `dart:io` | Directory/file watcher |
| `.env` **filesystem** | File path | Yes | Only accessible filesystem paths | No `dart:io` | Directory/file watcher |
| OS process variables | `Platform.environment` | Yes | Platform-dependent; not general app config source | No | Not live |
| JSON Flutter asset | Asset path | Not core Dart | Yes | Yes | Not production-hot-reloadable |
| HTTP JSON | HTTPS URL | Yes | Yes | Yes (CORS applies) | Poll, SSE, or WS |
| Explicit overrides | Map/key-value | Yes | Yes | Yes | Explicit updates |
| Custom | User-defined | Depends | Depends | Depends | Provider-defined |

**Critical distinctions:**

- `String.fromEnvironment` / `--dart-define`: compilation configuration; changing it generally requires rebuild/restart; runtime watch is not possible.
- `Platform.environment`: captured process environment, not a cross-process live subscription; changing a shell's environment does not update an already running Dart/Flutter application.
- Flutter assets (`rootBundle.loadString`): packaged resources; changed development assets may be seen through developer tooling, but a production asset is not an externally editable live configuration file.
- Web filesystem access and CORS are distinct from native `dart:io`; don't promise native file watching in browser apps.
- Remote JSON is client-visible. Never position it as a secure store for secrets or private credentials.

### 5.1 In-memory provider

- Support nested maps; defensively copy/freeze input.
- Useful for defaults, tests, and command-line/user overrides.
- Optional mutable implementation should issue invalidation events on explicit update.

### 5.2 JSON file provider

- Parse a UTF-8 JSON **object** at the root; reject unexpected root types with typed exception.
- Support `optional` and `reloadOnChange`.
- Distinguish file missing, access failure, decoding failure, and schema failure.
- Prefer watching the containing directory (filtered to target file) where possible, because deployment/editors often replace files atomically.
- Normalize file paths; avoid hard-coding working-directory assumptions.
- Provide documented policy for watching creation of optional files and deletion/rename events.

### 5.3 `.env` file provider

- Support common dotenv syntax: `KEY=value`, blank lines, comments, quoted values, `export KEY=value` if explicitly supported.
- Specify escape handling and whether interpolation `${NAME}` is supported; **do not silently expand untrusted content**.
- Treat dotenv values as strings; convert during typed access or binding.
- Support environment-specific files (`.env.development`, `.env.production`) through explicit entries or opt-in presets.
- Advise `.gitignore` for local sensitive files; warn that bundling any `.env` into Flutter/mobile/web exposes its contents.
- Document mapping from flat keys to nested properties (e.g., `APP__api__timeoutSeconds` → `api.timeoutSeconds`).

### 5.4 OS environment provider

- Native adapter reads `Platform.environment` at load; optional prefix filtering and nesting separator (`__`).
- A `reload()` might re-read the same captured process map; do **not** advertise active OS environment-variable monitoring.
- Treat keys containing underscores carefully: avoid guessing `BASE_URL` ↔ `baseUrl` mappings. Allow explicit mapping or documented normalization; favor exact paths or configurable case rules.

### 5.5 Flutter asset provider

- Use Flutter's asset bundle APIs behind a Flutter-only adapter/companion package.
- Assets must be declared in `pubspec.yaml`; document example.
- Provide `addJsonAsset()` and possibly `addDotEnvAsset()` without pulling Flutter SDK into core Dart package.
- Support async startup before `runApp` (use `WidgetsFlutterBinding.ensureInitialized()` when required).
- Do not claim file-system hot reload or runtime asset changes in a distributed release.

### 5.6 HTTP JSON provider

- Accept URI, injected client/transport, headers or authentication callback, timeouts, and `optional` policy.
- Prefer HTTPS, sensible response-size limits, status validation, and JSON-object root validation.
- HTTP requests must not repeatedly occur on each getter.
- Offer explicit reload and optional polling; add conditional requests with `ETag`/`If-None-Match` and/or `Last-Modified` later.
- For 304 responses keep the previously loaded provider snapshot.
- Ensure retry/backoff and errors don't trigger busy loops.
- Flutter web CORS requirements must be documented.
- Support cancellation/lifecycle shutdown where practical and cap simultaneous requests.
- Persistent offline cache is an **optional later feature**, not mandatory for the first HTTP release; clearly distinguish in-memory last-known-good from on-disk persisted cache.
- Advanced push transports (SSE/WebSocket) are later optional adapters; no need to block first release on them.

### 5.7 Advanced/future adapters

After core stability, consider command-line arguments, encrypted native storage or app-specific secure stores, remote configuration backends (Azure App Configuration, AWS AppConfig, etc.), and feature-flag providers. These should remain separate optional integrations and are not baseline acceptance criteria.

---

## 6. Configuration resolution and merging

### 6.1 Source ordering

The builder loads sources in registration order. **Later providers take precedence** over earlier providers for the same normalized key. An opt-in `standard()` preset may use:

1. In-memory defaults.
2. Base `appsettings.json` / base `.env` as explicitly configured.
3. Environment-specific JSON.
4. Remote HTTP JSON (if enabled).
5. Local dotenv overrides (if enabled).
6. OS process environment variables (native only).
7. Explicit overrides or command-line arguments (if supported).

This is a **suggested preset**, not a hardcoded global priority. Users can reorder providers. A Flutter/web preset must omit unavailable native providers.

### 6.2 Merge rules — must be specified and tested

- Recursively merge JSON objects/maps.
- A later scalar replaces an earlier scalar.
- A later array/list **replaces** the earlier array (do not merge by numeric index).
- Explicit `null` replaces an existing value; deletion semantics can be a later feature.
- Canonical paths use `.` for access; escaped path separators and nested key collisions need a clear policy.
- Avoid mutating provider-returned maps.
- Decide case sensitivity explicitly; don't let `API` vs `api` silently create ambiguous duplicates.
- For `.env` and OS environment values, avoid global speculative scalar coercion; binder and typed getters control conversion, with clear errors.
- The final effective configuration must be deterministic for a given ordered provider list.

Example:

```json
// Base file
{"api":{"baseUrl":"https://api.example.com","timeoutSeconds":30},"features":{"analytics":true}}
```

```json
// Development override
{"api":{"baseUrl":"https://dev.example.com"}}
```

```json
// Remote override
{"api":{"timeoutSeconds":15}}
```

Final effective map:

```json
{"api":{"baseUrl":"https://dev.example.com","timeoutSeconds":15},"features":{"analytics":true}}
```

### 6.3 Environment-selection conventions

- Support existing `aliasesResolver` and `tokenResolver`.
- Optional strict mode rejects unknown/missing requested environments; compatibility mode preserves fallback.
- `Envx.standard(environment: selectedEnvironment, ...)` should be a **preset**, not a replacement for explicit builder source composition.
- Never automatically load arbitrary files merely because their names match a convention unless the caller opted into that preset.
- Support named environments such as development, staging, testing, production without prescribing an enum.

---

## 7. Loading, validation, caching, and error handling

### 7.1 Loading contract

- `build()` returns `Future<T>` after complete initialization.
- `buildMonitor()` returns only after one validated initial snapshot exists.
- Share in-flight initialization work; parallel callers do not duplicate source requests.
- Freeze/copy published maps; recommend immutable typed models.
- No getter performs hidden disk or network I/O after initialization.

### 7.2 Validation

Allow a caller-supplied binder and validator:

```dart
final settings = await EnvxBuilder()
    .addSource(/* ... */)
    .buildMonitor<AppConfig>(
      AppConfig.fromJson,
      validate: (cfg) {
        if (cfg.api.baseUrl.isEmpty) {
          throw ConfigValidationException('api.baseUrl is required');
        }
        if (cfg.api.timeoutSeconds <= 0) {
          throw ConfigValidationException('api.timeoutSeconds must be positive');
        }
      },
    );
```

Support typed errors including source load errors, missing required config, parse errors, conversion/binding errors, validation failures, and disposed-manager operations. Provide safe origin/context (provider name/path or URL without credentials); **never include secret values by default**.

Recommended failure handling:

| Situation | Default behavior |
|---|---|
| Required source cannot load during startup | Initialization fails with source-specific exception. |
| Optional source missing during startup | Skip with diagnostic; document which other failures are considered optional. |
| Binding or validation fails at startup | Initialization fails even if source was optional (unless an explicit advanced policy says otherwise). |
| Watched source changes to invalid data | Keep previous valid snapshot; report failed reload. |
| HTTP refresh times out after successful load | Keep previous valid snapshot; report failure; retry on next scheduled/explicit reload. |
| Required source is removed after startup | Keep prior snapshot; report reload failure, rather than publishing a partial configuration. |
| Reload produces identical effective values | Do not publish a `ConfigChange<T>` event. |

Distinguish an optional provider's **absence** from an optional provider producing corrupt configuration; skipping corrupt or unauthorized sources by default can hide deployment defects.

### 7.3 Snapshot versioning and equality

- Increment version on successful **effective** configuration changes, not merely raw file-system events.
- Store timestamp and optionally provider provenance (source names/priority), redacted where needed.
- Compare effective structured values (deterministic deep equality or fingerprints) before publishing; allow a custom equality comparator for bound models.
- If a map changes but produces an equivalent `T`, specify whether to notify; default should be based on effective typed value/selected section, documented consistently.
- Replacing the current snapshot must be atomic; subscribers never observe half-merged configuration.

### 7.4 Cache policy

- Cache resolved settings and share in-flight async work.
- `reload()` explicitly invalidates/rebuilds all relevant sources while preserving source order.
- `reload()` should be serialized or coalesced if triggered concurrently.
- Support TTL/cache policy for HTTP later; do not conflate cache expiration with watcher subscriptions.
- Keep last-known-good **in memory** from initial monitored release; persistent cache requires explicit storage policy and security review.

---

## 8. Automatic change detection and options monitoring

### 8.1 Observation policy per source

| Source | Detection | Caveat |
|---|---|---|
| JSON/dotenv native file | `FileSystemEntity.watch()` / parent-directory events | Atomic replacement, platform variance, missing optional file creation. |
| In-memory mutable map | Explicit `set`/`update` calls | Only the mutable adapter emits events. |
| HTTP JSON | Scheduled polling with optional conditional GET | Polling is opt-in; respect timeouts/backoff. |
| HTTP SSE/WebSocket | Push notifications (future adapter) | Reconnect, heartbeat, security/authentication. |
| OS environment | **No general live watch** | Restart process or modify an actual watched source. |
| Flutter bundled asset | **No production hot watch** | Use remote config for runtime changes. |
| `--dart-define` | **No runtime watch** | New build/restart required. |

### 8.2 Reload pipeline

1. An enabled watchable source emits **invalidation**.
2. Debounce bursts (e.g., 100–300 ms, configurable); coalesce simultaneous signals.
3. Reload ordered provider sources; preserve required/optional policies.
4. Deep merge the newly loaded maps in precedence order.
5. Bind and validate typed model, plus required registered sections.
6. On error, retain current snapshot unchanged and emit a separate diagnostic/error event.
7. On equal effective configuration, no change notification.
8. On real change, increment snapshot version, atomically swap, broadcast `ConfigChange<T>`.
9. Dispose watchers, timers, subscriptions, and HTTP resources **owned** by the manager when manager is closed. Never close an externally injected client unless ownership was explicitly transferred.

### 8.3 Subscription semantics

- `changes` is broadcast and supports multiple independent listeners.
- Listeners only get **successful value changes**; not every file event, HTTP 304, or failed refresh.
- Subscribers can synchronously read `currentValue` after a change event and see that event's new version.
- Initial value is obtained through `currentValue` after initialization; document that the stream doesn't replay it by default.
- Expose `errors`/`statusChanges` separately from value changes (e.g., last reload error, last successful refresh).
- Prevent slow listeners or errors in listener callbacks from corrupting the manager's state.
- Optional `monitorSection` only signals when that effective section changes.

### 8.4 `OptionsSnapshot<T>` consistency

When a request/operation begins, capture a snapshot:

```dart
final requestOptions = settings.snapshot(); // OptionsSnapshot<AppConfig>
await processRequest(requestOptions.value);
```

A reload during the operation must not change `requestOptions.value`. This depends on immutable/copy-on-publication models. The library can't force users' arbitrary custom class `T` to be immutable; document the invariant and offer immutable maps as the default storage representation.

---

## 9. Flutter integration

### 9.1 Flutter bootstrap

The Flutter adapter should support bundle-based and remote sources, then initialize before `runApp`:

```dart
const appEnv = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'development',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = await EnvxBuilder()
      .addJsonAsset('assets/config/appsettings.json')
      .addJsonAsset(
        'assets/config/appsettings.$appEnv.json',
        optional: true,
      )
      .addHttpJson(
        Uri.parse('https://config.example.com/$appEnv.json'),
        optional: true,
      )
      .buildMonitor<AppConfig>(AppConfig.fromJson);

  runApp(MyApp(settings: settings));
}
```

**Important:** `.addJsonAsset()` and `.addHttpJson()` may be extension methods from imported Flutter/HTTP adapters, not necessarily members of `envx` core. Ensure shipped examples include all correct imports and dependencies.

### 9.2 Reactive widget adapter

Provide an optional adapter using `ValueListenable<T>`, compatible with `ValueListenableBuilder<T>`:

```dart
final notifier = settings.asValueListenable();

ValueListenableBuilder<AppConfig>(
  valueListenable: notifier,
  builder: (context, config, _) => Text(config.api.baseUrl),
);
```

- Keep Flutter SDK types out of core.
- Document who owns and disposes the adapter's subscription/notifier.
- Make its initial value available immediately because builder startup is awaited.
- Rebuild only on successful/effective value updates; avoid unnecessary UI rebuilds.
- Provide optional Riverpod/GetIt/Provider/Bloc examples, not mandatory runtime dependencies.

---

## 10. Concrete example: .NET-style configuration and DI

Base `assets/config/appsettings.json` or native `config/appsettings.json`:

```json
{
  "api": {
    "baseUrl": "https://api.example.com",
    "timeoutSeconds": 30
  },
  "features": {
    "enableAnalytics": true,
    "enableNotifications": false
  }
}
```

Development overlay:

```json
{
  "api": {
    "baseUrl": "https://dev-api.example.com"
  },
  "features": {
    "enableAnalytics": false
  }
}
```

Proposed monitored native application:

```dart
const selectedEnv = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'development',
);

Future<void> main() async {
  final manager = await EnvxBuilder()
      .addMemory({'api': {'timeoutSeconds': 30}})
      .addJsonFile('config/appsettings.json', reloadOnChange: true)
      .addJsonFile(
        'config/appsettings.$selectedEnv.json',
        optional: true,
        reloadOnChange: true,
      )
      .addEnvironmentVariables(prefix: 'APP__', separator: '__')
      .buildMonitor<AppConfig>(
        AppConfig.fromJson,
        validate: validateAppConfig,
      );

  final apiOptions = manager.monitorSection<ApiSettings>(
    'api',
    ApiSettings.fromJson,
  );

  final service = ApiService(apiOptions);
  await service.fetchData();

  // Shut down manager when application lifecycle ends.
  await manager.dispose();
}

class ApiService {
  ApiService(this._options);
  final OptionsMonitor<ApiSettings> _options;

  Future<void> fetchData() async {
    final uri = Uri.parse(_options.currentValue.baseUrl);
    // Perform the request using the current validated URI.
  }
}
```

Example nested process environment override (native only):

```bash
APP__api__timeoutSeconds=10 dart run -DAPP_ENV=production bin/server.dart
```

Specify the actual supported CLI flag usage when publishing examples; `APP_ENV` selection is compile-time, while `APP__api__timeoutSeconds` is process environment data. These are intentionally different mechanisms.

---

## 11. Packaging, API surface, and dependency policy

### 11.1 Recommended approach

Start with a small cross-platform core and platform-specific public entry points. Separate packages may be created when helpful, but **do not introduce a monorepo solely for architecture aesthetics**.

Possible logical decomposition:

```text
envx (pure Dart core)
  lib/envx.dart
  lib/src/core/
    config_source.dart
    config_builder.dart
    config_manager.dart
    config_snapshot.dart
    config_merger.dart
    config_errors.dart
    config_values.dart
    options.dart
  lib/src/parsers/
    json_config_parser.dart
    dotenv_parser.dart
  lib/src/environment/
    environment_registry.dart
    environment_service.dart
    default_resolvers.dart

envx_io or lib/envx_io.dart (native IO adapters)
    json_file_source.dart
    dotenv_file_source.dart
    platform_environment_source.dart

envx_http or lib/envx_http.dart (HTTP adapter)
    http_json_source.dart
    conditional_request_support.dart

envx_flutter (Flutter SDK companion, if needed)
    json_asset_source.dart
    value_listenable_options_adapter.dart
```

**Decision rule:** use conditional imports/separate entry points to preserve web compatibility. If Flutter SDK APIs are required, a companion Flutter package is likely cleaner. For HTTP, either an injectable transport or a small optional adapter can prevent core dependency bloat.

### 11.2 Backward compatibility

- Keep `Environment.register`, `EnvironmentInstance`, `aliasesResolver`, and `tokenResolver` working in `1.x` unless migration tests demonstrate unavoidable issues.
- Do not silently alter fallback or exception behavior for current `1.x` users.
- Mark problematic dynamic define behavior as deprecated with a tested alternative where feasible.
- Introduce new APIs beside the old. Reserve breaking signature changes (`Future<C>?` → `Future<C>`, strict errors as universal default, possible environment API redesign) for a planned `2.0.0`.
- Maintain clear deprecation notes, upgrade examples, and changelog entries.
- Keep SDK minimum compatible with the package's declared range unless a feature demonstrably requires a higher version; if raised, document why and reflect in semver/CI matrix.

---

## 12. Security, observability, and production safeguards

### Security baseline

- No secrets in Flutter asset bundles, downloadable remote JSON, published `.env` files, or client-side `--dart-define` values. These are discoverable by users.
- Require/support HTTPS for production remote configuration; document cleartext HTTP as a development-only risk.
- Accept injected authentication headers/callbacks rather than embedding static bearer tokens in client code.
- Protect URLs from leaking credentials in exceptions/logs. Redact tokens/passwords/keys from configuration diagnostics and examples.
- Set reasonable remote response-size limits and timeouts to reduce resource exhaustion.
- Do not evaluate executable expressions, import code, or execute arbitrary commands from configuration values.
- Persistent offline cache should be opt-in, platform-aware, and never automatically persist secrets.
- Avoid exposing a public endpoint for internal server-only configuration.

### Diagnostics

Expose non-sensitive instrumentation such as:

- Provider identifier/type, load duration, last success, last error.
- Successful reload count and failed reload count.
- Effective configuration version and updated timestamp.
- Whether the current snapshot is live, unchanged, or using last-known-good.
- Optional per-key provenance (`api.baseUrl` came from provider X) **without printing the value**.
- Debug/verbose logging hooks must be opt-in and redact sensitive fields.

Avoid turning diagnostics into a new global logging subsystem. Accept a small callback/logger abstraction or adapter.

---

## 13. Testing and quality gates

### 13.1 Automated tests — minimum coverage matrix

| Group | Required tests |
|---|---|
| Legacy API | Existing environment selection/aliases, unknown values, empty configs, default fallback, async failures, missing resolvers. |
| Compile-time env | Regression demonstration for old dynamic lookup and tests/examples of const injected environment values; verify compiled/non-JIT behavior where feasible. |
| Parsers | JSON object/array/invalid JSON, Unicode, `.env` blanks/comments/quotes/escapes/empty values, malformed input. |
| File source | Present/missing optional/missing required, unreadable file, atomic replacement, file removal, creation of previously optional file. |
| Env source | Prefix stripping, nested `__` mapping, case collisions, string-to-typed conversion, native-only tests. |
| HTTP source | 200/304/404/500, invalid JSON, timeout, network failure, headers, oversized body, conditional request, retry policy. |
| Merge | Map recursion, scalar override, list replacement, explicit null, case policy, no input mutation, provider ordering. |
| Binding | `getString/getInt/getBool`, section binding, missing required keys, conversion failures, validation failures. |
| Initialization | Async startup, concurrent load deduplication, required/optional source policy, no getter I/O after startup. |
| Monitoring | Debounce, duplicate file events, simultaneous reload coalescing, no notification when equal, emission when changed, version monotonicity. |
| Atomicity | Validation failure preserves old snapshot; subscribers never see a partially merged model; error stream receives failure. |
| Options | Stable `Options<T>`, fixed `OptionsSnapshot<T>`, live `OptionsMonitor<T>`, filtered section updates. |
| Lifecycle | Proper cancellation of file watchers/timers/subscriptions; external clients not inadvertently closed; disposed manager behavior. |
| Flutter | Asset loading on mobile/web as feasible, `ValueListenable` update and disposal widget tests, no `dart:io` import in web build. |
| Security | Error redaction; remote body size cap; no secret values in default logs; no remote code execution. |

### 13.2 CI and release controls

Add a CI workflow triggered by pull requests and pushes to `main`:

```bash
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
dart pub publish --dry-run
```

Check installed SDK compatibility when choosing exact flags. For Flutter companions, run `flutter analyze` and `flutter test` in their respective package jobs and include a web build or compile smoke test. Consider multi-OS filesystem watcher tests (Linux/Windows/macOS), marking flaky OS-specific expectations separately.

Fix docs deployment branch `master` → `main`. Validate published README examples by compiling/running them, not merely documenting aspirational interfaces. Treat PANA scoring as an informative metric, not the primary quality goal.

---

## 14. Documentation deliverables

Prepare clear, runnable docs and examples covering:

1. Five-minute quick start: old compile-time resolver API and new builder API, separately labeled.
2. Basic Dart CLI/server with `appsettings.json` and environment overlays.
3. `.env` file and OS environment variables, including nested-key mapping.
4. Remote HTTP configuration, timeouts, optional source, and HTTPS/CORS notes.
5. File watching and live monitor; how to observe errors and dispose resources.
6. `Options<T>`, `OptionsSnapshot<T>`, `OptionsMonitor<T>` semantics and constructor injection.
7. Flutter asset bootstrap and `ValueListenableBuilder` changes.
8. Configuration precedence/merge/null behavior with examples.
9. Validation, fallback, debugging, and security recommendations.
10. Migration guide, CHANGELOG, API docs, troubleshooting, and runnable sample apps.

Docs should prominently distinguish compile-time definitions, process environment variables, bundled assets, and externally hosted runtime configuration. These are not interchangeable.

---

## 15. Phased implementation plan for Codex Work

Implement sequentially, but deliver each phase as a self-contained, tested change. Version numbers are **proposed**, not fixed; decide after inspecting the current published package state.

### Phase 0 — Stabilization (`1.0.x`)

**Tasks:**

- Read repository history and verify current pub.dev version; assess current behavior under `dart analyze`, `dart test`, and compiled Dart.
- Resolve B-01 through B-10 without unannounced breaking behavior.
- Establish const `APP_ENV` injection guidance and tests.
- Fix GitHub Pages branch mismatch; add PR CI.
- Reconcile version/changelog; improve README and public documentation.
- Improve resolver collision tests and explicit error documentation.

**Exit criteria:** baseline API still works; package analyze/test/format pass; compile-time selection example is reliable; CI is active; no publishing performed without authorization.

### Phase 1 — Provider foundation (`1.1.x`)

**Tasks:**

- Implement `ConfigSource`, in-memory source, JSON/dotenv parsers, native file sources, and native environment adapter.
- Introduce `EnvxBuilder.addSource()` and adapter-specific fluent methods.
- Define source-order precedence, nested merge, list/null behavior, and raw typed getters.
- Implement startup validation errors and optional-source policy.
- Add parser/provider/merge tests and a basic Dart CLI/server example.

**Exit criteria:** a Dart application loads general + environment-specific JSON and optionally `.env`/process overrides into a validated map/model; ordering is deterministic, with thorough tests.

### Phase 2 — Typed configuration and DI (`1.2.x`)

**Tasks:**

- Implement typed `build<T>(binder)`, model validation callback, snapshots, and cached initialization.
- Implement `Options<T>`, `OptionsSnapshot<T>`, and section binding.
- Add example for constructor injection and a request-scoped snapshot.
- Formalize typed exceptions and duplicate in-flight load handling.

**Exit criteria:** typed options and snapshots have distinct, documented lifetimes; `build()` returns a validated typed model and never silently returns invalid configuration; existing API unaffected.

### Phase 3 — Monitoring and remote configuration (`1.3.x`)

**Tasks:**

- Implement `WatchableConfigSource`, native file events, debouncing/coalescing, and manager disposal.
- Implement `OptionsMonitor<T>`, `ConfigChange<T>`, section monitoring, atomic reload, and diagnostic error/status stream.
- Add HTTP JSON provider with injectable client, request timeout, status handling, and opt-in polling.
- Add at least in-memory last-known-good behavior and validation-safe reload.
- Add comprehensive watch, HTTP, concurrency, and failure tests.

**Exit criteria:** editing a watched JSON file updates `currentValue` and notifies consumers exactly once for an effective change; invalid updates retain the old model; remote polling uses the same pipeline; shutdown closes owned watchers.

### Phase 4 — Flutter adapter and ergonomics (`1.4.x`)

**Tasks:**

- Add Flutter assets adapter and UI `ValueListenable` bridge without introducing Flutter into the Dart core.
- Demonstrate initialization before `runApp` and reactive widget updates.
- Provide optional dependency injection recipes (GetIt, Riverpod, etc.) and Flutter web platform checks.
- Add opt-in `Envx.standard(...)` convenience presets for native and Flutter contexts.

**Exit criteria:** Flutter mobile and web examples compile; the UI observes runtime remote changes, not falsely promised local asset/compile-time changes; adapters have safe lifecycle semantics.

### Phase 5 — Maturity / optional `2.0.0`

**Tasks:**

- Evaluate breaking simplifications (`Future<C>?` legacy signatures, strict defaults, deprecated factory APIs).
- Support HTTP conditional requests and robust caching strategy if not yet available.
- Consider file watcher portability, source provenance/debugging, remote SSE/WebSocket push, persistent encrypted cache where appropriate, or configuration backend integrations.
- Publish migration guide and track real-user feedback before removing legacy symbols.

**Exit criteria:** major-version breaking changes have migration instructions, explicit user authorization for release, and regression tests; speculative advanced features do not block a stable core.

---

## 16. Definition of done for the complete roadmap

The roadmap is functionally complete when all of the following are true:

- [ ] Existing `envx` consumers have a documented, tested compatibility path.
- [ ] Environment selection no longer relies on dynamic `String.fromEnvironment` behavior.
- [ ] JSON, dotenv, native environment, in-memory, HTTP, and Flutter asset sources exist for appropriate platforms.
- [ ] Sources compose deterministically with documented precedence and deep-merge rules.
- [ ] Users can bind to typed models, access primitive keys, bind sections, and validate required settings.
- [ ] `Options<T>`, `OptionsSnapshot<T>`, and `OptionsMonitor<T>` are supported with distinct semantics.
- [ ] Watchable native file sources and optional HTTP polling trigger validated, atomic reloads.
- [ ] Effective changes notify subscribers; identical values and failed reloads do not publish new configurations.
- [ ] Reload failures preserve last-known-good settings and are separately observable.
- [ ] Flutter apps can bootstrap configuration and react through an optional `ValueListenable` bridge.
- [ ] All watchers, subscriptions, timers, and owned resources are properly disposed.
- [ ] Tests cover precedence, failures, monitoring, concurrency, DI, and platform limitations.
- [ ] CI, examples, docs, migration notes, and release metadata are coherent and passing.
- [ ] No application secrets are encouraged in client-visible configuration sources.

---

## 17. Working instructions to give Codex Work

> **Task:** Implement this roadmap in `https://github.com/arlamend7/dart_envx`. Read `ENVX_CODEX_WORK_IMPLEMENTATION_SPEC.md` completely, inspect the latest repository, and first identify any drift from the documented baseline. Keep `Environment.register()` backward compatible in `1.x`. Execute the phases in order, in small coherent changes, running format/analyze/tests and adding tests before declaring each phase done. Prefer small, cross-platform abstractions and optional IO/HTTP/Flutter adapters over a heavyweight monolithic dependency. Don't claim that OS variables, bundled Flutter assets, or `--dart-define` can be watched in deployed apps. Provide an implementation summary, files changed, tests run, API examples, trade-offs, compatibility notes, and remaining follow-ups after each phase. Do not publish a package or create release tags without my explicit permission. If a public API detail remains uncertain, choose the simplest extensible Dart design, document the decision, and continue with working code rather than leaving the project at architecture-only stage.

### Preferred first Codex Work execution

Start with **Phase 0 + Phase 1** as the first coherent implementation effort. Do not attempt HTTP monitoring, Flutter adapters, and an options system in the same unreviewed first patch. Phase 1 establishes the merging and source contracts that all later work depends on.

---

## 18. Reference links

**Project**

- Repository: https://github.com/arlamend7/dart_envx
- Package: https://pub.dev/packages/envx
- Existing environment service: https://github.com/arlamend7/dart_envx/blob/main/lib/src/environment_service.dart
- Existing environment registry: https://github.com/arlamend7/dart_envx/blob/main/lib/src/environment_registry.dart
- Existing entry point: https://github.com/arlamend7/dart_envx/blob/main/lib/envx.dart
- Existing docs workflow: https://github.com/arlamend7/dart_envx/blob/main/.github/workflows/deploy-docs.yml

**Platform and patterns**

- Dart compile-time environment declarations: https://api.dart.dev/dart-core/String/String.fromEnvironment.html
- Dart process environment: https://api.dart.dev/dart-io/Platform/environment.html
- Dart filesystem watchers: https://api.dart.dev/dart-io/FileSystemEntity/watch.html
- Flutter `ValueListenable`: https://api.flutter.dev/flutter/foundation/ValueListenable-class.html
- Angular application initializer: https://angular.dev/api/core/provideAppInitializer
- ASP.NET Core configuration providers: https://learn.microsoft.com/aspnet/core/fundamentals/configuration/
- ASP.NET Core options pattern: https://learn.microsoft.com/aspnet/core/fundamentals/configuration/options
- `flutter_dotenv` (ecosystem comparison): https://pub.dev/packages/flutter_dotenv

---

**End of implementation specification.**
