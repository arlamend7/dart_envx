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
  resolver: aliasesResolver({
    AppEnvironment.development: ['development', 'dev'],
    AppEnvironment.production: ['production', 'prod'],
  }),
  defaultEnvironment: AppEnvironment.development,
  defineKey: 'APP_ENV',
);

Future environmentInitialize() async {
  environment = await _register.current();
}
