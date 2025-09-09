import 'package:envx/envx.dart';

import 'enum/app_environment.dart';
import 'models/example_config.dart';

ExampleConfig? environment;

var _register = Environment.register(
  configuration: {
    AppEnvironment.development: () async => const ExampleConfig('https://dev.example.com'),
    AppEnvironment.production: () async => const ExampleConfig('https://example.com'),
  },
  resolver: _parseEnv,
  defaultEnvironment: AppEnvironment.development,
);

AppEnvironment? _parseEnv(String value) {
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

Future environmentInitialize() async {
  environment = await _register.current();
}
