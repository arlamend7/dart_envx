# Migrating from 1.0.0 to 2.0.0

Existing `Environment.register`, `EnvironmentInstance`, aliases, tokens, nullable
futures, async factories, and default fallback remain available. Caching, strict
selection, and collision checks are opt-in. The major version introduces no forced signature migration.

## Reliable compiler definitions

Read arbitrary compiler keys at a const application call site:

```dart
const selected = String.fromEnvironment('MY_ENV', defaultValue: 'development');
// Add environment: selected to your existing Environment.register(...) call.
final config = await environments.getEnvironment(selected);
```

The final line also works on 1.0.0. In 2.0.0, passing `environment: selected`
configures `current()` and `currentKey()`. If omitted, the fixed `APP_ENV` const
lookup is used. Empty or unrecognized values fall back by default.

The old `defineKey` parameter is deprecated. A custom key still invokes the old
dynamic lookup for compatibility with existing consumers, but Dart does not guarantee it in AOT.
The default `APP_ENV` lookup no longer depends on that behavior. This corrects
the old fallback that could pass the literal key name to a resolver. Do not rely
on a resolver interpreting `APP_ENV` itself as an environment value.

```sh
dart run -DAPP_ENV=production example/envx_example.dart
```

Use the same literal key in your own const expression. The bundled example above
uses `APP_ENV`; an application using `MY_ENV` would pass `-DMY_ENV=production`. Flutter uses
`flutter run --dart-define=APP_ENV=production`. Changing a compiler definition
requires rebuilding/restarting; it is not a runtime process environment variable.

## Explicit performance and error behavior

- `cache: true` shares each environment's pending factory future and caches
  success. Failures are evicted. Call `clearCache()` to reload on the next read.
  Clearing does not cancel futures already returned to callers.
- `strict: true` requires a registered default and rejects empty, unknown, or
  unregistered selections. Legacy signatures may throw synchronously on lookup;
  factory errors remain synchronous/asynchronous according to the factory unless
  caching wraps the invocation in a future.
- `strictCollisions: true` on alias/token resolvers rejects normalized aliases
  assigned to different enum values. Repeated aliases for the same value are fine.
- Defaults remain uncached and use last-wins aliases and fallback. Resolver and
  factory exceptions are never swallowed.

## Adopting providers

Environment selection and configuration loading are independent. Use the selected
environment to choose an explicit overlay path, then compose providers through
`EnvxBuilder`. You can migrate one application/service at a time. The old factory
API can also return a model loaded by a builder.

`buildValues()` returns `Future<ConfigValues>`; `build<T>()` returns `Future<T>`.
Neither returns a nullable future. Use `get` and `contains` for optional values.
Monitoring and options interfaces in the original proposal are not shipped in
2.0.0; see the [roadmap](ROADMAP.md).
