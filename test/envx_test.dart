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
    final env = Environment.register(
      configuration: {
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
    final env = Environment.register(
      configuration: {TestEnv.dev: () async => const TestConfig('dev')},
      resolver: parse,
      defaultEnvironment: TestEnv.dev,
    );

    final cfg = await env.getEnvironment('unknown');
    expect(cfg?.value, 'dev');
  });

  test('string environments work without resolver', () async {
    final env = Environment.register(
      configuration: {'dev': () async => const TestConfig('dev')},
      defaultEnvironment: 'dev',
    );

    final cfg = await env.getEnvironment('dev');
    expect(cfg?.value, 'dev');
  });

  test('throws when typed environment lacks resolver', () {
    expect(
      () => Environment.register(
        configuration: {TestEnv.dev: () async => const TestConfig('dev')},
        defaultEnvironment: TestEnv.dev,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
