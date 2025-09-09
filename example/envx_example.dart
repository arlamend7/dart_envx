import 'package:envx/envx.dart';

import './environment/enum/app_environment.dart';
import './environment/models/example_config.dart';

import './environment/configs/environment.development.dart' as development;
import './environment/configs/environment.production.dart' as production;

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

Future<void> main() async {
  await environmentInitialize();

  print('Base URL: ${environment?.baseUrl}');
}
