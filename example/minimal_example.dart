import 'package:envx/envx.dart';

Future<void> main() async {
  final settings = await EnvxBuilder().addMemory({
    'api': {'baseUrl': 'https://api.example.com', 'timeoutSeconds': 30},
  }).addMemory({
    'api': {'timeoutSeconds': 10},
  }).buildValues();

  print(settings.getString('api.baseUrl')); // https://api.example.com
  print(settings.getInt('api.timeoutSeconds')); // 10
}
