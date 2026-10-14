// Native Dart example. Run from the repository root:
//   dart run example/envx_example.dart
//   dart run -DENVIRONMENT=production example/envx_example.dart
// Flutter assets need a custom loader; see the README's Flutter recipe.
import 'package:envx/envx_io.dart';

const environment =
    String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

Future<void> main() async {
  final settings = await EnvxBuilder()
      .addJsonFile('example/config/appsettings.json')
      .addJsonFile(
        'example/config/appsettings.$environment.json',
        optional: true,
      )
      // Optional process overrides, e.g. APP__api__timeoutSeconds=10.
      // Missing variables leave the JSON values unchanged.
      .addEnvironmentVariables(prefix: 'APP__')
      .buildValues();

  final api = settings.getSection('api');
  print('API: ${api.getString('baseUrl')}');
  print('Timeout: ${api.getInt('timeoutSeconds')}s');
}
