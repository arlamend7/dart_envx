# Load appsettings with envx

Load a base JSON file, optionally overlay the selected environment, and read your
settings. Later sources override earlier values.

## Run the example

From a checkout of the [repository](https://github.com/arlamend7/dart_envx):

```sh
dart pub get
dart run example/envx_example.dart
dart run -DENVIRONMENT=production example/envx_example.dart
```

This is a **native Dart** example. It includes the files it loads under
[`example/config/`](https://github.com/arlamend7/dart_envx/tree/main/example/config).
For Flutter bundled assets, use the custom-loader recipe in the
[package README](https://pub.dev/packages/envx#initialize-a-flutter-application).

## Code

```dart
import 'package:envx/envx_io.dart';

const environment =
    String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

Future<void> main() async {
  final settings = await EnvxBuilder()
      .addJsonFile('example/config/appsettings.json')
      .addJsonFile(
        'example/config/appsettings.$environment.json',
        optional: true,
      )
      .addEnvironmentVariables(prefix: 'APP__')
      .buildValues();

  final api = settings.getSection('api');
  print('API: ${api.getString('baseUrl')}');
  print('Timeout: ${api.getInt('timeoutSeconds')}s');
}
```

In your application, replace `example/config/` with the directory containing your
configuration files. Native file paths are not Flutter asset-bundle paths.

## Configuration files

`example/config/appsettings.json`:

```json
{
  "api": {
    "baseUrl": "https://api.example.com",
    "timeoutSeconds": 30
  }
}
```

`example/config/appsettings.development.json`:

```json
{
  "api": {
    "baseUrl": "https://dev.example.com"
  }
}
```

The default output is:

```text
API: https://dev.example.com
Timeout: 30s
```

The development URL overrides the base URL. The timeout stays at 30 because the
overlay does not replace it. A missing optional file is skipped; invalid JSON or
an unreadable file still fails.

## Override a value

On macOS/Linux, supply a process variable:

```sh
APP__api__timeoutSeconds=10 dart run example/envx_example.dart
```

In PowerShell:

```powershell
$env:APP__api__timeoutSeconds = '10'
dart run example/envx_example.dart
Remove-Item Env:APP__api__timeoutSeconds
```

The prefix `APP__` is stripped and `__` creates nested keys. Missing variables do
not overwrite the file settings. `ENVIRONMENT` is a compiler definition read at
a const call site; `APP__...` variables are native process values.

## More examples

- [Typed settings and validation](https://github.com/arlamend7/dart_envx/blob/main/example/configuration_example.dart): JSON, dotenv, process overrides, and constructor injection.
- [In-memory configuration](https://github.com/arlamend7/dart_envx/blob/main/example/minimal_example.dart): a small example requiring no files.
- [Advanced walkthrough](https://github.com/arlamend7/dart_envx/blob/main/example/advanced_example.dart): aliases, custom sources, caching, and failure handling.

The [README](https://pub.dev/packages/envx) covers Flutter assets, named compiler
overrides, and model binding. Live HTTP refresh is not part of the current API.
