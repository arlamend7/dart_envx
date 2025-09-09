`envx` resolves compile-time environment configuration for Dart and Flutter
applications.

## Features

- Custom resolver to map a `String` environment value to any key type.
- Compile-time `APP_ENV` (or custom) variable with a configurable default.
- Access the current configuration or any specific environment's config.

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

  final config = await env.current(fallbackValue: 'prod');
  print('Base URL: ${config?.baseUrl}');
}
```

## Additional information

This library avoids global state. Create an [Environment] instance whenever
you need to resolve configuration.

