// Native-only example. Run from the repository root so fixture paths resolve:
//   dart run example/configuration_example.dart
//   dart run -DAPP_ENV=production example/configuration_example.dart
// macOS/Linux process override:
//   APP__api__timeoutSeconds=5 dart run example/configuration_example.dart
import 'package:envx/envx_io.dart';

/// Application-owned immutable settings with explicit string conversion.
class ApiSettings {
  const ApiSettings(this.baseUrl, this.timeoutSeconds);
  final String baseUrl;
  final int timeoutSeconds;

  factory ApiSettings.fromJson(Map<String, Object?> json) {
    final api = ConfigValues(json).getSection('api');
    return ApiSettings(api.getString('baseUrl'), api.getInt('timeoutSeconds'));
  }
}

class ApiService {
  const ApiService(this.settings);
  final ApiSettings settings;

  void describe() => print('API: ${settings.baseUrl}; '
      'timeout: ${settings.timeoutSeconds}s');
}

// APP_ENV selects the overlay at compilation. APP__ values are native process
// strings. Neither changes automatically in an already running application.
const selectedEnvironment =
    String.fromEnvironment('APP_ENV', defaultValue: 'development');

Future<void> main() async {
  final settings = await EnvxBuilder()
      // Lowest precedence: application defaults.
      .addMemory({
        'api': {'timeoutSeconds': 30},
      })
      .addJsonFile('example/config/appsettings.json')
      .addJsonFile(
        'example/config/appsettings.$selectedEnvironment.json',
        optional: true,
      )
      // This committed fixture contains public demonstration values only.
      .addDotEnvFile('example/config/overrides.env', prefix: 'APP__')
      // Optional local overrides; .env is excluded from Git and publication.
      .addDotEnvFile('.env', optional: true, prefix: 'APP__')
      // Highest precedence: matching native process variables.
      .addEnvironmentVariables(prefix: 'APP__')
      .build(ApiSettings.fromJson, validate: (settings) {
        final uri = Uri.tryParse(settings.baseUrl);
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
          throw const ConfigValidationException('API URL must use HTTPS.');
        }
        if (settings.timeoutSeconds <= 0) {
          throw const ConfigValidationException(
              'API timeout must be positive.');
        }
      });

  print('Environment: $selectedEnvironment');
  ApiService(settings).describe();
}
