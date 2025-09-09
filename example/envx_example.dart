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
