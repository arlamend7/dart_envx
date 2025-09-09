import 'package:envx/envx.dart';

import 'enum/app_environment.dart';
import 'models/example_config.dart';

import './configs/environment.development.dart' as development;
import './configs/environment.production.dart' as production;

ExampleConfig? environment;

var _register = Environment.register(
  configuration: {
    AppEnvironment.development: development.environment,
    AppEnvironment.production: production.environment,
  },
  resolver: _parseEnv,
  defaultEnvironment: AppEnvironment.development,
  defineKey: 'APP_ENV',
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
