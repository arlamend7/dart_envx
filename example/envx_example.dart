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
  final env = Environment.register<AppEnvironment, ExampleConfig>(
    configuration: {
      AppEnvironment.development: () async =>
          const ExampleConfig('https://dev.example.com'),
      AppEnvironment.production: () async =>
          const ExampleConfig('https://example.com'),
    },
    resolver: parseEnv,
    defaultEnvironment: AppEnvironment.development,
  );

  final config = await env.current(fallbackValue: 'prod');
  print('Base URL: ${config?.baseUrl}');
}
