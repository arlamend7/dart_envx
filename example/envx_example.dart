import 'environment/environment.dart';

Future<void> main() async {
  await environmentInitialize();

  final config = environment;
  print('Base URL: ${config?.baseUrl}');
}
