# Configuration contracts (2.0.0)

## A small public API

`EnvxBuilder` offers `addMemory`, `addSource`, `buildValues`, and `build`.
Import `package:envx/envx_io.dart` for `addJsonFile`, `addDotEnvFile`, and
`addEnvironmentVariables`. It re-exports the core so one import is sufficient.

Each `ConfigSource.load()` returns a complete `Map<String, Object?>`. Use only
JSON-compatible values: strings, booleans, finite numbers, null, string-keyed
maps, and lists. Unsupported objects fail. Cyclic collections are unsupported;
custom sources must produce finite trees. Memory inputs are copied at registration;
other sources are copied immediately after load. Neither merges nor consumers
can mutate the source data.

```dart
class ApplicationSource implements ConfigSource {
  ApplicationSource(this.read);
  final Future<String> Function() read;

  @override
  Future<Map<String, Object?>> load() async => parseJsonConfig(await read());
}
```

Custom providers own their I/O, timeouts, and resource cleanup. There is no
implicit source disposal protocol in this release. Errors from custom sources
propagate; custom providers must redact sensitive exception text themselves.

## Precedence and initialization

Sources load sequentially, in registration order. Later values override earlier
ones. Objects recursively merge; scalars, lists, and null replace earlier values.
No filenames are loaded implicitly. A missing optional file contributes an empty
map; malformed content always fails. Empty builders return an empty immutable map.

Concurrent builds on an unchanged builder share the same in-flight source load.
Each build runs its own binder and validator. A source added while loading affects
only builds started after that addition. Failures clear the in-flight cache.
Completed builds are independent: the next build rereads sources, while existing
models remain unchanged. No automatic reload, versioned snapshots, last-known-good
manager, options contracts, or monitoring is implied by this API.

## Typed paths

`getString`, `getInt`, `getDouble`, `getBool`, and `getSection` require non-null
values. Missing/null throws `ConfigMissingException`; incompatible values throw
`ConfigTypeException`. `get(path)` returns null for both missing and explicit null;
`contains(path)` distinguishes them.

- Strings are not produced by coercing other types.
- Integers accept integer values and decimal strings such as `"30"`; doubles are
  not silently rounded. Numeric bounds follow Dart's platform representation.
- Doubles accept finite numbers or parseable finite numeric strings.
- Booleans accept booleans or case-insensitive `"true"` / `"false"`, not `1` / `0`.
- Sections must be maps. Lists cannot be traversed by index in a path.
- Paths use `.` separators. Escape literal dots as `\.` and backslashes as `\\`.
  In Dart, `r'api\.host.value'` addresses the `value` key under `api.host`.
- Empty segments, dangling escapes, and unsupported escapes throw `ArgumentError`.
- Exact case is preserved: `api` and `API` are distinct keys.

`ConfigValues.values` gives direct access to literal keys, including keys that
cannot be expressed as a path (such as the empty string). Configuration errors
omit values and paths by default to avoid revealing sensitive keys.

## Dotenv grammar

Supported: blank lines, `#` comments, `KEY=value`, optional `export `, empty values,
single quotes, and double quotes. Keys match `[A-Za-z_][A-Za-z0-9_]*`. Values stay
strings. Duplicate assignments use the last value. CRLF, Unicode, and an initial
UTF-8 BOM are accepted.

Single-quoted strings are literal. Double quotes support `\n`, `\r`, `\t`, `\\`,
and `\"`; other escapes fail. Quoted values must be on one line, followed only by
whitespace or a comment. Unquoted `#` begins a comment only at the beginning or
when preceded by whitespace. Interpolation, shell substitution, and multiline
values are not supported; `${NAME}` remains literal text.

`parseDotEnv()` produces a flat immutable string map. File providers call
`nestEnvironmentValues()` to apply prefix filtering and nesting. To parse strings
without reading files, use either public parser directly.

## Environment key mapping

Both dotenv and process providers use an exact, case-sensitive prefix and a
configurable nesting separator (default `__`). `APP__api__BASE_URL` with prefix
`APP__` becomes `{'api': {'BASE_URL': value}}`; no camelCase conversion is guessed.
Empty segments and scalar/object collisions (such as `APP__a` plus `APP__a__b`)
fail in either insertion order. Use a prefix to avoid importing unrelated process
values. Tests may inject a copied `environment` map.

`Platform.environment` is the process's view of environment variables. Rebuilding
configuration does not make another shell's changes visible to that process.
Compiler definitions use `const String.fromEnvironment` and are a separate input.

## Failures and validation

| Failure | Result |
| --- | --- |
| Missing required file / unreadable file | `ConfigSourceException` |
| Missing optional file | Empty provider; earlier defaults remain |
| Invalid UTF-8, dotenv, or non-object/malformed JSON | `ConfigParseException` |
| Unsupported input / typed value conversion | `ConfigTypeException` |
| Missing required path or explicit null | `ConfigMissingException` |
| Binder throws | Redacted `ConfigBindingException` |
| Validator throws `ConfigValidationException` | Original validation message |
| Validator throws another exception | Redacted `ConfigValidationException` |

Native file paths are resolved at provider construction. Files are decoded as
UTF-8. Optional status skips only native not-found errors, never permission errors
or directories. This release loads complete files; applications should use trusted,
reasonably sized local files. File watching, HTTP timeouts/size limits, and atomic
monitor reloads belong to the later monitoring milestone.
