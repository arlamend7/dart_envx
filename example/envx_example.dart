// A self-contained tour of envx's public API. No files or network are required.
// Run from the package root:
//   dart run example/envx_example.dart
//   dart run -DAPP_ENV=production example/envx_example.dart
// Native file/process providers: example/configuration_example.dart.
import 'package:envx/envx.dart';

// Compiler declarations must be read at a const call site. For Flutter, pass
// --dart-define=APP_ENV=production instead of Dart's -DAPP_ENV=production.
const selectedEnvironment =
    String.fromEnvironment('APP_ENV', defaultValue: 'development');

enum AppEnvironment { development, production }

/// An application-owned immutable model; envx needs no generated serializer.
class AppSettings {
  const AppSettings({
    required this.baseUrl,
    required this.timeoutSeconds,
    required this.analyticsEnabled,
  });

  final String baseUrl;
  final int timeoutSeconds;
  final bool analyticsEnabled;

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final values = ConfigValues(json);
    return AppSettings(
      baseUrl: values.getString('api.baseUrl'),
      timeoutSeconds: values.getInt('api.timeoutSeconds'),
      analyticsEnabled: values.getBool('features.analytics'),
    );
  }
}

/// Constructor injection works without a service locator or global singleton.
class ApiService {
  const ApiService(this.settings);
  final AppSettings settings;

  void describe() {
    print('API: ${settings.baseUrl}');
    print('Timeout: ${settings.timeoutSeconds}s');
    print('Analytics: ${settings.analyticsEnabled}');
  }
}

/// A custom source can adapt an existing asynchronous JSON loader.
class JsonTextSource implements ConfigSource {
  const JsonTextSource(this.read);
  final Future<String> Function() read;

  @override
  Future<Map<String, Object?>> load() async => parseJsonConfig(await read());
}

Future<void> main() async {
  print('1. Select an environment with enum aliases');
  final environments = Environment.register(
    configuration: {
      AppEnvironment.development: () async => 'https://dev.example.com',
      AppEnvironment.production: () async => 'https://api.example.com',
    },
    defaultEnvironment: AppEnvironment.development,
    resolver: aliasesResolver({
      AppEnvironment.development: ['development', 'dev', 'local'],
      AppEnvironment.production: ['production', 'prod'],
    }, strictCollisions: true),
    environment: selectedEnvironment,
    cache: true,
    strict: true,
  );
  final baseUrl = await environments.current();
  // Legacy lookups retain nullable futures. Validate explicitly at startup.
  if (baseUrl == null) throw StateError('No environment configuration.');
  print('Selected: ${environments.currentKey().name}');

  print('\n2. Merge defaults, JSON, and explicit overrides');
  final builder = EnvxBuilder()
      .addMemory({
        'api': {'baseUrl': baseUrl, 'timeoutSeconds': 30},
        'features': {'analytics': false},
      })
      .addSource(JsonTextSource(() async => '{"api":{"timeoutSeconds":20}}'))
      .addMemory({
        'features': {'analytics': true},
      });
  final settings = await builder.build(
    AppSettings.fromJson,
    validate: (settings) {
      if (settings.timeoutSeconds <= 0) {
        throw const ConfigValidationException('API timeout must be positive.');
      }
    },
  );
  ApiService(settings).describe();

  print('\n3. Parse dotenv strings and read nested values');
  final overrides = nestEnvironmentValues(
    parseDotEnv('APP__api__timeoutSeconds=10\nAPP__features__analytics=false'),
    prefix: 'APP__',
  );
  final values = await EnvxBuilder().addMemory(overrides).buildValues();
  print(
      'Dotenv timeout: ${values.getSection('api').getInt('timeoutSeconds')}s');
  print('Dotenv analytics: ${values.getBool('features.analytics')}');
  print('Optional label: ${values.get('label') ?? 'not configured'}');

  print('\n4. Distinguish explicit null from a missing key');
  final optional = ConfigValues({'label': null});
  print('label exists: ${optional.contains('label')}');
  print('other exists: ${optional.contains('other')}');

  print('\n5. Cache factories and explicitly refresh');
  var factoryCalls = 0;
  final cached = Environment.register(
    configuration: {'development': () async => ++factoryCalls},
    defaultEnvironment: 'development',
    environment: 'development',
    cache: true,
  );
  await Future.wait([cached.current()!, cached.current()!]);
  print('Factory calls after two reads: $factoryCalls'); // 1
  cached.clearCache();
  await cached.current();
  print('Factory calls after refresh: $factoryCalls'); // 2

  print('\n6. Reject invalid settings before exposing a model');
  try {
    await EnvxBuilder().addMemory({'timeout': 0}).build(
      (json) => ConfigValues(json).getInt('timeout'),
      validate: (timeout) {
        if (timeout <= 0) {
          throw const ConfigValidationException('Timeout must be positive.');
        }
      },
    );
  } on ConfigValidationException catch (error) {
    // This is an intentional failure demonstration. Application startup should
    // fail or use an explicit fallback policy; never silently accept this value.
    print('Expected validation failure: ${error.message}');
  }
}
