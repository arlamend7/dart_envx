# envx

Select an environment, combine configuration sources, and pass validated settings
to your Dart or Flutter application without global state or code generation.

The library provides:

- Typed environment factories with enum aliases, fallback, and optional caching.
- An ordered builder for memory, JSON, dotenv, native files, and process values.
- Immutable merged values with primitive getters and section access.
- Application-owned typed models and validation before startup completes.
- A small `ConfigSource` contract for your own loaders, without runtime dependencies.

**Version 2.0.0** adds layered configuration providers while preserving the
existing environment API. Existing 1.0.0 consumers can follow the
[migration guide](doc/MIGRATION.md). See the [changelog](CHANGELOG.md) for release
details and the [validation record](doc/VALIDATION.md) for quality checks.

## Contents

- [Install and check compatibility](#install-and-check-compatibility)
- [Run the examples](#run-the-examples)
- [Quick start](#quick-start)
- [Select environments with strings or enums](#select-environments-with-strings-or-enums)
- [Choose fallback and strict behavior](#choose-fallback-and-strict-behavior)
- [Combine sources and control precedence](#combine-sources-and-control-precedence)
- [Read typed values and sections](#read-typed-values-and-sections)
- [Bind models and inject settings](#bind-models-and-inject-settings)
- [Load native files and process variables](#load-native-files-and-process-variables)
- [Add a custom source](#add-a-custom-source)
- [Initialize a Flutter application](#initialize-a-flutter-application)
- [Cache factories and rebuild configuration](#cache-factories-and-rebuild-configuration)
- [Override configuration in tests](#override-configuration-in-tests)
- [Handle failures and troubleshoot](#handle-failures-and-troubleshoot)
- [Resources and source layout](#resources-and-source-layout)

## Install and check compatibility

The examples below target **2.0.0**. To use the repository checkout in a Dart or
Flutter application:

```yaml
dependencies:
  envx:
    path: ../dart_envx
```

Run `dart pub get`, or `flutter pub get` in a Flutter application. Once 2.0.0 is
available on pub.dev, use the hosted dependency instead:

```yaml
dependencies:
  envx: ^2.0.0
```

| Requirement | Support |
| --- | --- |
| Dart SDK | `>=3.0.0 <4.0.0`; locally checked on 3.0.7 and 3.13.4 |
| Flutter SDK | Not required by the package; Flutter apps can consume the core |
| Runtime dependencies | None |
| Core import | `package:envx/envx.dart` — native and web |
| Native providers | `package:envx/envx_io.dart` — accessible files and process variables |

The native entry point also exports the core, so use one import for a native
application. Do not import `src/` files. Native filesystem paths are different
from Flutter asset paths. [Validation results](doc/VALIDATION.md) distinguish
local checks from the broader CI matrix.

## Run the examples

From the repository root:

```sh
dart pub get
dart run example/minimal_example.dart
dart run example/envx_example.dart
dart run -DAPP_ENV=production example/envx_example.dart
dart run example/configuration_example.dart
```

| Example | Demonstrates |
| --- | --- |
| [Minimal quick start](example/minimal_example.dart) | Two sources, precedence, typed reads; no setup beyond dependencies |
| [Main package example](example/envx_example.dart) | Enum selection, custom JSON loading, merging, typed models, validation, dotenv parsing, optional values, caching |
| [Native providers](example/configuration_example.dart) | JSON overlays, dotenv files, process overrides, HTTPS validation, constructor injection |

The main example is self-contained: it reads no files and makes no network calls.
It is referenced by `example: example/envx_example.dart` in the package's
[pubspec](pubspec.yaml). That field is custom descriptive metadata; pub.dev finds
the Example tab through conventional paths such as `example/envx_example.dart`.

With no overrides, the native example selects development and prints
`API: https://dev.example.com; timeout: 15s`. Its public
[dotenv fixture](example/config/overrides.env) overrides the JSON timeout of 30.
A local `.env` or process variable can override it again. Unknown selections in
the main example fail because it enables strict mode.

## Quick start

This complete program also exists as [minimal_example.dart](example/minimal_example.dart):

```dart
import 'package:envx/envx.dart';

Future<void> main() async {
  final settings = await EnvxBuilder()
      .addMemory({
        'api': {'baseUrl': 'https://api.example.com', 'timeoutSeconds': 30},
      })
      .addMemory({
        'api': {'timeoutSeconds': 10},
      })
      .buildValues();

  print(settings.getString('api.baseUrl')); // https://api.example.com
  print(settings.getInt('api.timeoutSeconds')); // 10
}
```

Subsequent snippets use `package:envx/envx.dart` unless another import is shown.
Place snippets containing `await` inside an `async` function. Each recipe declares
its own inputs; the model and custom-source recipes also define reusable classes.

## Select environments with strings or enums

Use environment factories when each environment has its own configuration object
or asynchronous initialization. Read compiler keys at a **const call site**:

```dart
const selected =
    String.fromEnvironment('APP_ENV', defaultValue: 'development');

final environments = Environment.register(
  configuration: {
    'development': () async => 'https://dev.example.com',
    'production': () async => 'https://api.example.com',
  },
  defaultEnvironment: 'development',
  environment: selected,
);
final baseUrl = await environments.current();
```

String keys need no resolver. For enum keys, provide aliases or your own resolver:

```dart
enum AppEnvironment { development, production }

final environments = Environment.register(
  configuration: {
    AppEnvironment.development: () async => 'https://dev.example.com',
    AppEnvironment.production: () async => 'https://api.example.com',
  },
  defaultEnvironment: AppEnvironment.development,
  resolver: aliasesResolver({
    AppEnvironment.development: ['dev', 'local'],
    AppEnvironment.production: ['prod', 'live'],
  }, strictCollisions: true),
  environment: 'prod',
);
final production = await environments.current();
final development = await environments.getEnvironment('local');
final explicit = await environments.getEnvironmentByKey(AppEnvironment.production);
```

Aliases are case-insensitive and recognize enum names by default. Set
`caseInsensitive: false` or `allowEnumName: false` to change those rules.
`strictCollisions: true` rejects a normalized alias mapped to different values;
without it, the last assignment wins for compatibility.

For an existing token map, replace the resolver with:

```dart
final resolver = tokenResolver<AppEnvironment>({
  'dev': AppEnvironment.development,
  'prod': AppEnvironment.production,
}, strictCollisions: true);
```

A custom `EnvResolver<K>` returns a key or null for unknown input. Resolver exceptions
propagate. Custom compiler keys work the same way: read
`const String.fromEnvironment('MY_ENV')` and pass its value as `environment`.
The deprecated dynamic `defineKey` option is not reliable in compiled AOT code.

## Choose fallback and strict behavior

| Operation / option | Behavior |
| --- | --- |
| `current()` | Resolves explicit `environment`, or fixed const `APP_ENV`, and loads configuration |
| `currentKey()` | Resolves the key without loading its factory |
| `getEnvironment(raw)` | Resolves a string through the configured resolver |
| `getEnvironmentByKey(key)` | Looks up the typed key directly |
| Default selection behavior | Unknown or missing selections/configurations fall back to the default |
| `strict: true` | Requires a registered default; rejects missing/unrecognized selection and unregistered configuration lookups |
| Legacy return type | `Future<C>?`; the future can be absent when neither requested nor default configuration exists |
| `buildValues()` / `build<T>()` | Required `Future<ConfigValues>` / `Future<T>`; initialization failures throw |

Enable `strict: true` on registration when an environment typo should stop startup.
Check nullable legacy results before using them. A throwing factory is an error;
it does not trigger fallback to another factory.

The native example treats the selected value as an overlay filename. Its optional
missing overlay leaves the base settings intact; that is a separate policy from
strict environment registration.

## Combine sources and control precedence

Builder order is the complete precedence rule: **later sources win**.

```dart
final values = await EnvxBuilder()
    .addMemory({
      'api': {'host': 'base.example.com', 'timeout': 30},
      'regions': ['west', 'east'],
      'label': 'default',
    })
    .addMemory({
      'api': {'timeout': 10},
      'regions': ['central'],
      'label': null,
    })
    .buildValues();
```

| Path | Result | Rule |
| --- | --- | --- |
| `api.host` | `base.example.com` | Unchanged nested keys survive |
| `api.timeout` | `10` | Later scalar replaces earlier value |
| `regions` | `['central']` | Lists replace wholesale |
| `label` | `null` | Explicit null replaces, rather than deletes |

Objects merge recursively. A scalar can replace a map, and a map can replace a
scalar. Keys are case-sensitive: `api` and `API` are different. Inputs are copied;
result maps and lists are deeply immutable. No conventional filenames are loaded
unless explicitly added to the builder.

## Read typed values and sections

```dart
final values = ConfigValues({
  'api': {'timeout': '15', 'enabled': 'true', 'ratio': '0.5'},
  'label': null,
  'literal.key': 'hello',
});
final api = values.getSection('api');
final timeout = api.getInt('timeout'); // 15
final enabled = api.getBool('enabled'); // true
final ratio = api.getDouble('ratio'); // 0.5
final literal = values.getString(r'literal\.key'); // hello
final label = values.get('label') ?? 'Untitled';
final hasLabel = values.contains('label'); // true, even though it is null
final hasOther = values.contains('other'); // false
```

| Getter | Accepts |
| --- | --- |
| `getString(path)` | Strings only |
| `getInt(path)` | Integers or decimal integer strings; no rounding of doubles |
| `getDouble(path)` | Finite numbers or finite numeric strings |
| `getBool(path)` | Booleans or case-insensitive `true` / `false` strings |
| `getSection(path)` | An object, returned as another `ConfigValues` |
| `get(path)` | Any stored value; null for absent or explicitly null |
| `contains(path)` | Presence, including explicit null |

Required getters reject missing/null values and incompatible types. Paths use dots;
escape literal dots as `\.` and backslashes as `\\`. Lists are returned as values,
not traversed by numeric path segments. Access `values.values` for the immutable
raw map. Full conversion and path rules are in the [provider guide](doc/CONFIGURATION.md).

## Bind models and inject settings

Keep the model in your application. Use the binder to convert strings from dotenv
or process providers, then validate before constructing dependent services:

```dart
class ApiSettings {
  const ApiSettings(this.baseUrl, this.timeoutSeconds);
  final String baseUrl;
  final int timeoutSeconds;

  factory ApiSettings.fromJson(Map<String, Object?> json) {
    final api = ConfigValues(json).getSection('api');
    return ApiSettings(api.getString('baseUrl'), api.getInt('timeoutSeconds'));
  }
}

class ApiService {
  const ApiService(this.settings);
  final ApiSettings settings;
}

Future<ApiService> createService() async {
  final settings = await EnvxBuilder()
      .addMemory({
        'api': {'baseUrl': 'https://api.example.com', 'timeoutSeconds': '30'},
      })
      .build(ApiSettings.fromJson, validate: (settings) {
        if (settings.timeoutSeconds <= 0) {
          throw const ConfigValidationException('API timeout must be positive.');
        }
      });
  return ApiService(settings);
}
```

`build` infers the model type. It also accepts your generated `fromJson` factory
when its signature matches. Binders receive a deeply immutable map; copy it first
if a serializer needs mutable input. Prefer immutable model fields so settings
remain stable after startup. No DI framework is required; an existing container
can register the completed model or service after `await createService()`.

## Load native files and process variables

Use `package:envx/envx_io.dart` for these providers:

```dart
import 'package:envx/envx_io.dart';

const selected =
    String.fromEnvironment('APP_ENV', defaultValue: 'development');

Future<void> main() async {
  final values = await EnvxBuilder()
      .addJsonFile('example/config/appsettings.json')
      .addJsonFile('example/config/appsettings.$selected.json', optional: true)
      .addDotEnvFile('example/config/overrides.env', prefix: 'APP__')
      .addDotEnvFile('.env', optional: true, prefix: 'APP__')
      .addEnvironmentVariables(prefix: 'APP__')
      .buildValues();
  print(values.getString('api.baseUrl'));
  print(values.getInt('api.timeoutSeconds'));
}
```

Run from the repository root to use the included fixtures. JSON roots must be
objects. Files are UTF-8; relative paths resolve when the source is registered.
`optional: true` skips **only missing files**, not malformed content, invalid
encoding, directories, or permission failures.

A dotenv file can contain:

```dotenv
# Public example values, not secrets.
APP__api__timeoutSeconds=15
APP__features__analytics=false
```

The `APP__` prefix is removed and `__` creates nested objects. Thus
`APP__api__timeoutSeconds` becomes `api.timeoutSeconds`. Both prefix and separator
are configurable. Case is preserved; `BASE_URL` is not guessed to mean `baseUrl`.
Scalar/object collisions such as `APP__api` plus `APP__api__timeout` fail.

Dotenv supports comments, empty values, `export`, and single/double quotes.
Double quotes support common escapes; interpolation and shell execution are not
performed. Use `parseDotEnv(text)` and `nestEnvironmentValues(...)` when the text
already comes from another loader, as the main example demonstrates.

Override the native example on macOS/Linux:

```sh
APP__api__timeoutSeconds=5 dart run -DAPP_ENV=production example/configuration_example.dart
```

Or in PowerShell:

```powershell
$env:APP__api__timeoutSeconds = '5'
dart run -DAPP_ENV=production example/configuration_example.dart
Remove-Item Env:APP__api__timeoutSeconds
```

`APP_ENV` above is a compiler setting; `APP__api__timeoutSeconds` is a process
variable. Reading process variables does not subscribe to changes in another shell.

## Add a custom source

Adapt an existing text loader with the single-method `ConfigSource` contract:

```dart
class JsonTextSource implements ConfigSource {
  const JsonTextSource(this.read);
  final Future<String> Function() read;

  @override
  Future<Map<String, Object?>> load() async => parseJsonConfig(await read());
}

Future<ConfigValues> loadSettings() {
  return EnvxBuilder()
      .addMemory({'timeout': 30})
      .addSource(JsonTextSource(() async => '{"timeout":10}'))
      .buildValues();
}
```

The main example runs this pattern. A source returns a complete JSON-compatible
map on each load. Its owner controls resource cleanup, transport timeouts, and
safe error messages. Use a loader your application already owns for remote data
or Flutter assets; 2.0.0 does not include a first-party HTTP or asset adapter.

## Initialize a Flutter application

After adding envx to an existing Flutter app, this complete `lib/main.dart`
awaits settings before building widgets and injects them through a constructor:

```dart
import 'package:envx/envx.dart';
import 'package:flutter/material.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://dev.example.com',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await EnvxBuilder()
      .addMemory({'api': {'baseUrl': apiBaseUrl}})
      .buildValues();
  runApp(ConfigApp(settings: settings));
}

class ConfigApp extends StatelessWidget {
  const ConfigApp({super.key, required this.settings});
  final ConfigValues settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('envx configuration')),
        body: Center(child: Text(settings.getString('api.baseUrl'))),
      ),
    );
  }
}
```

Run with `flutter run --dart-define=API_BASE_URL=https://api.example.com`.
The core works with Flutter web; do not import `envx_io.dart` in browser code.

To load bundled JSON using the custom source above, import
`package:flutter/services.dart` and add
`JsonTextSource(() => rootBundle.loadString('assets/config/appsettings.json'))`
to the builder. Create that file and declare it in the **consuming application's**
pubspec:

```yaml
flutter:
  assets:
    - assets/config/appsettings.json
```

This uses Flutter's loader through your custom source. The package's own pubspec
does not declare application assets. Bundled assets and compiler definitions
require rebuild/deployment to change; this initialization code is not a reactive
monitor. Keep secrets out of client-visible settings, including downloaded JSON.

## Cache factories and rebuild configuration

For legacy factories, caching is opt-in:

```dart
var calls = 0;
final environments = Environment.register(
  configuration: {'dev': () async => ++calls},
  defaultEnvironment: 'dev',
  environment: 'dev',
  cache: true,
);
await environments.current(); // 1
await environments.current(); // 1: same cached result
// Invalidate when the application explicitly chooses to refresh.
environments.clearCache();
await environments.current(); // 2
```

Concurrent reads share the pending factory when caching is enabled. Failures are
evicted and can be retried. Clearing the cache does not cancel already returned
futures. Without caching, each lookup invokes the factory again.

Builders have different semantics: concurrent builds on the same unchanged source
list share source loading, while each caller binds/validates independently. A
build after completion loads sources again. Reading an already returned model or
`ConfigValues` performs no I/O. `MemoryConfigSource` copies its input at registration;
mutating the original map will not update later builds.

There are no watchers, automatic reloads, or `OptionsMonitor` in 2.0.0.
Applications explicitly replace their settings only after a new build succeeds.
Future lifecycle APIs are listed in the [roadmap](doc/ROADMAP.md).

## Override configuration in tests

Use memory as the final provider for a deterministic override:

```dart
final values = await EnvxBuilder()
    .addMemory({'api': {'baseUrl': 'https://api.example.com', 'timeout': 30}})
    .addMemory({'api': {'baseUrl': 'https://test.example.com', 'timeout': 1}})
    .buildValues();
assert(values.getInt('api.timeout') == 1);
```

For native process-provider tests, inject a map rather than modifying the process:

```dart
// Import package:envx/envx_io.dart for this extension.
final values = await EnvxBuilder()
    .addEnvironmentVariables(
      prefix: 'APP__',
      environment: {'APP__api__timeout': '5'},
    )
    .buildValues();
assert(values.getInt('api.timeout') == 5);
```

Create independent builders or registries per test. No global reset is needed.

## Handle failures and troubleshoot

Catch configuration exceptions at your application startup boundary. For example:

```dart
try {
  final values = await EnvxBuilder()
      .addMemory({'port': '8080'})
      .buildValues();
  print(values.getInt('port'));
} on ConfigException catch (error) {
  // Report a safe diagnostic and stop startup or apply your explicit policy.
  print(error.message);
  rethrow;
}
```

| Symptom | Explanation / action |
| --- | --- |
| Unexpected environment | Check the const compiler key and aliases; opt into strict selection |
| Required value is null/missing | Use `contains`/`get` for optional values or provide a default source |
| Conversion fails | Dotenv/process values are strings; use typed getters or explicit binder conversion |
| Optional file still throws | Optional skips absence only; fix malformed content or permissions |
| Browser cannot import native providers | Import `envx.dart` and supply a web-compatible custom source |
| File changes are not reflected | Build again explicitly; existing values do not reload themselves |
| A factory is called repeatedly | Enable `cache: true` if that factory should be cached |
| A model fails validation | Correct the input; validation runs before the model is returned |

Typed errors include `ConfigSourceException`, `ConfigParseException`,
`ConfigMissingException`, `ConfigTypeException`, `ConfigBindingException`, and
`ConfigValidationException`. Invalid path syntax throws `ArgumentError`; legacy
strict registration/lookups can throw `StateError`. Parser and binder diagnostics
omit values. Custom provider errors and explicit validation messages are your
application's responsibility. See [error contracts](doc/CONFIGURATION.md#failures-and-validation).

## Resources and source layout

| Location | Purpose |
| --- | --- |
| `lib/envx.dart` | Cross-platform public API |
| `lib/envx_io.dart` | Native providers and fluent extensions |
| `example/` | Runnable quick start, feature tour, native configuration fixtures |
| `test/` | Compatibility, parsing, merging, validation, concurrency, and native I/O tests |
| `tool/compile_smoke.dart` | AOT/JavaScript compiler-selection regression check |

- [Provider semantics and parser grammar](doc/CONFIGURATION.md)
- [Migration and compatibility](doc/MIGRATION.md)
- [Versioned capability roadmap](doc/ROADMAP.md)
- [API reference](https://arlamend7.github.io/dart_envx/)
- [Release checks](doc/RELEASING.md) and [measured validation results](doc/VALIDATION.md)

The hosted API reference reflects the latest docs deployment. Run `dart doc` for
this checkout. The implementation measured **160/160 PANA points**, with all
public API elements documented; pub.dev recalculates its score after publication.
