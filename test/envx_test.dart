import 'package:envx/envx.dart';
import 'package:test/test.dart';

enum TestEnv { dev, prod }

class TestConfig {
  const TestConfig(this.value);
  final String value;
}

TestEnv? parse(String input) {
  switch (input) {
    case 'prod':
      return TestEnv.prod;
    case 'dev':
      return TestEnv.dev;
    default:
      return null;
  }
}

void main() {
  test('resolves current and specific environments', () async {
    final env = Environment<TestEnv, TestConfig>(
      configs: {
        TestEnv.dev: () async => const TestConfig('dev'),
        TestEnv.prod: () async => const TestConfig('prod'),
      },
      resolver: parse,
      defaultEnvironment: TestEnv.dev,
    );

    expect(env.currentKey(fallbackValue: 'prod'), TestEnv.prod);

    final cfg = await env.current(fallbackValue: 'prod');
    expect(cfg?.value, 'prod');

    final devCfg = await env.getEnvironment('dev');
    expect(devCfg?.value, 'dev');
  });

  test('falls back to default when resolver misses', () async {
    final env = Environment<TestEnv, TestConfig>(
      configs: {TestEnv.dev: () async => const TestConfig('dev')},
      resolver: parse,
      defaultEnvironment: TestEnv.dev,
    );

    final cfg = await env.getEnvironment('unknown');
    expect(cfg?.value, 'dev');
  });
}
