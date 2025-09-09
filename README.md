`envx` resolves compile-time environment configuration for Dart and Flutter
applications.

## Features

- Custom resolver to map a `String` environment value to any enum.
- Compile-time `APP_ENV` (or custom) variable with a configurable default.
- Access the current configuration or any specific environment's config.

## Getting started

Define your environment enum, configuration class, and resolver. Then create an
`Envx` instance with your configuration map.

## Usage

```dart
import 'package:envx/envx.dart';

enum AppEnvironment { development, production }

class ExampleConfig {
  const ExampleConfig(this.baseUrl);
  final String baseUrl;
}

AppEnvironment parseEnv(String value) {
  switch (value) {
    case 'production':
    case 'prod':
      return AppEnvironment.production;
    default:
      return AppEnvironment.development;
  }
}

void main() {
  const configs = <AppEnvironment, ExampleConfig>{
    AppEnvironment.development: ExampleConfig('https://dev.example.com'),
    AppEnvironment.production: ExampleConfig('https://example.com'),
  };

  final envx = Envx<AppEnvironment, ExampleConfig>(
    values: configs,
    resolver: parseEnv,
  );

  final ExampleConfig? config = envx.environment;
  print('Base URL: ${config?.baseUrl}');
}
```

## Additional information

This library is synchronous and maintains no global state beyond compile-time
constants.

