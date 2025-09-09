import 'package:envx/envx.dart';
import 'package:test/test.dart';

enum AppEnvironment { development, staging, production }

class SimpleConfig {
  const SimpleConfig(this.name);
  final String name;
}

AppEnvironment parseEnv(String value) {
  switch (value) {
    case 'staging':
      return AppEnvironment.staging;
    case 'production':
    case 'prod':
      return AppEnvironment.production;
    default:
      return AppEnvironment.development;
  }
}

void main() {
  const configs = <AppEnvironment, SimpleConfig>{
    AppEnvironment.development: SimpleConfig('dev'),
    AppEnvironment.staging: SimpleConfig('stage'),
    AppEnvironment.production: SimpleConfig('prod'),
  };

  final envx = Envx<AppEnvironment, SimpleConfig>(
    values: configs,
    resolver: parseEnv,
  );

  test('returns default environment configuration', () {
    final SimpleConfig? current = envx.environment;
    expect(current?.name, 'dev');
  });

  test('configFor retrieves specified environment', () {
    final SimpleConfig? staging = envx.configFor(AppEnvironment.staging);
    expect(staging?.name, 'stage');
  });

  test('supports custom key and default value', () {
    final custom = Envx<AppEnvironment, SimpleConfig>(
      values: configs,
      resolver: parseEnv,
      key: 'CUSTOM_ENV',
      defaultValue: 'production',
    );
    final AppEnvironment env = custom.currentEnvironment();
    expect(env, AppEnvironment.production);
  });
}
