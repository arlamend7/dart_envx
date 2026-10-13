import 'package:envx/envx.dart';

// Exercises the web-compatible entry point and const injection in AOT/JS.
const selected = String.fromEnvironment('CUSTOM_ENV', defaultValue: 'dev');
Future<void> main() async {
  final environment = Environment.register(
    configuration: {'dev': () async => 'dev', 'prod': () async => 'prod'},
    defaultEnvironment: 'dev',
    environment: selected,
  );
  final actual = await environment.current();
  if (actual != selected) throw StateError('Const selection failed.');
  final defaultDefine = Environment.register(
    configuration: {'dev': () async => 'dev', 'prod': () async => 'prod'},
    defaultEnvironment: 'dev',
  );
  const expected = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  if (await defaultDefine.current() != expected) {
    throw StateError('Fixed APP_ENV selection failed.');
  }
  final values = await EnvxBuilder().addMemory({'enabled': true}).buildValues();
  if (!values.getBool('enabled')) throw StateError('Core loading failed.');
  print('Compile smoke passed: $actual');
}
