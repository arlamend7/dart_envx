`envx` resolves compile-time environment configuration for Dart and Flutter
applications without relying on global state.

## Features

- Custom resolver to map a `String` environment value to any key type.
- Compile-time `APP_ENV` (or custom) variable with a configurable default.
- Access the current configuration or any specific environment's config.

## Installation

Add the package to your project:

```bash
dart pub add envx
```

## Getting started

Define your environment enum (or key type), configuration class, and resolver.
Then create an [Environment] instance with your configuration map.

## Usage

```dart
import 'package:envx/envx.dart';

enum AppEnvironment { development, production }

class ExampleConfig {
  const ExampleConfig(this.baseUrl);
  final String baseUrl;
}

AppEnvironment? parseEnv(String value) {
  switch (value) {
    case 'production':
    case 'prod':
      return AppEnvironment.production;
    case 'development':
    case 'dev':
      return AppEnvironment.development;
    default:
      return null;
  }
}

Future<void> main() async {
  final env = Environment.register(
    configuration: {
      AppEnvironment.development:
          () async => const ExampleConfig('https://dev.example.com'),
      AppEnvironment.production:
          () async => const ExampleConfig('https://example.com'),
    },
    resolver: parseEnv,
    defaultEnvironment: AppEnvironment.development,
  );

  final config = await env.current();
  print('Base URL: ${config?.baseUrl}');
}
```

## PANA score

This package is configured to achieve a perfect [pana](https://pub.dev/packages/pana)
score of 160. Run the following to verify:

```bash
dart pub global activate pana
dart pub global run pana .
```

## Additional information

Create an [Environment] instance whenever you need to resolve configuration;
the library avoids global state so multiple instances can coexist.

