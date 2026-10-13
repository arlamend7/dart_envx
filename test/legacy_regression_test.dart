import 'dart:async';
import 'package:envx/envx.dart';
import 'package:test/test.dart';

enum AppEnv { dev, prod }

void main() {
  test('explicit const selection is independent of default key', () async {
    const selected = String.fromEnvironment('ENVX_TEST', defaultValue: 'prod');
    final env = Environment.register(
        configuration: {'dev': () async => 1, 'prod': () async => 2},
        defaultEnvironment: 'dev',
        environment: selected);
    expect(await env.current(), 2);
    expect(env.currentKey(), 'prod');
  });

  test('missing keys fall back; empty registry returns nullable future',
      () async {
    final env = Environment.register(
        configuration: {'dev': () async => 1}, defaultEnvironment: 'dev');
    expect(await env.getEnvironmentByKey('missing'), 1);
    expect(await env.getEnvironment(''), 1);
    final empty = Environment.register<String, int>(
        configuration: {}, defaultEnvironment: 'dev');
    expect(empty.current(), isNull);
  });

  test('uncached factories remain default; failures propagate', () async {
    var calls = 0;
    final env = Environment.register(
        configuration: {'dev': () async => ++calls}, defaultEnvironment: 'dev');
    expect(await env.current(), 1);
    expect(await env.current(), 2);
    final failure = Environment.register<String, int>(configuration: {
      'dev': () async => throw StateError('failure'),
    }, defaultEnvironment: 'dev');
    await expectLater(failure.current(), throwsStateError);
  });

  test('cache shares in-flight calls and clears explicitly', () async {
    var calls = 0;
    final ready = Completer<int>();
    final env = Environment.register(configuration: {
      'dev': () {
        calls++;
        return ready.future;
      }
    }, defaultEnvironment: 'dev', cache: true);
    final a = env.current();
    final b = env.getEnvironmentByKey('missing');
    expect(identical(a, b), isTrue);
    ready.complete(1);
    expect(await a, 1);
    expect(await env.current(), 1);
    expect(calls, 1);
    env.clearCache();
    expect(await env.current(), 1);
    expect(calls, 2);
  });

  test('failed cached futures are evicted', () async {
    var calls = 0;
    final env = Environment.register(configuration: {
      'dev': () async {
        if (++calls == 1) throw StateError('failure');
        return calls;
      }
    }, defaultEnvironment: 'dev', cache: true);
    await expectLater(env.current(), throwsStateError);
    expect(await env.current(), 2);
  });

  test('old failed request does not evict newer cache entry', () async {
    final old = Completer<int>();
    var calls = 0;
    final env = Environment.register(configuration: {
      'dev': () {
        return ++calls == 1 ? old.future : Future.value(2);
      }
    }, defaultEnvironment: 'dev', cache: true);
    final failed = expectLater(env.current(), throwsStateError);
    env.clearCache();
    expect(await env.current(), 2);
    old.completeError(StateError('old failure'));
    await failed;
    expect(await env.current(), 2);
    expect(calls, 2);
  });

  test('strict mode rejects missing/unknown environments', () {
    expect(
        () => Environment.register<String, int>(
            configuration: {}, defaultEnvironment: 'dev', strict: true),
        throwsStateError);
    final env = Environment.register(
        configuration: {'dev': () async => 1},
        defaultEnvironment: 'dev',
        strict: true);
    expect(() => env.getEnvironment('missing'), throwsStateError);
    expect(() => env.getEnvironment(''), throwsStateError);
    expect(() => env.getEnvironmentByKey('missing'), throwsStateError);
  });

  test('alias collision opt-in preserves legacy last-wins', () {
    final aliases = {
      AppEnv.dev: ['x'],
      AppEnv.prod: ['X']
    };
    expect(aliasesResolver(aliases)('x'), AppEnv.prod);
    expect(() => aliasesResolver(aliases, strictCollisions: true),
        throwsArgumentError);
    expect(
        () => aliasesResolver({
              AppEnv.dev: ['prod'],
              AppEnv.prod: []
            }, strictCollisions: true),
        throwsArgumentError);
    expect(
        aliasesResolver({
          AppEnv.dev: ['DEV']
        }, strictCollisions: true)(' dev '),
        AppEnv.dev);
    expect(aliasesResolver<AppEnv>({})('dev'), isNull);
    expect(
        aliasesResolver({
          AppEnv.dev: ['X']
        }, caseInsensitive: false, allowEnumName: false)('x'),
        isNull);
  });

  test('tokens normalize and check collisions on request', () {
    final tokens = {'dev': AppEnv.dev, ' DEV ': AppEnv.prod};
    expect(tokenResolver(tokens)('Dev'), AppEnv.prod);
    expect(() => tokenResolver(tokens, strictCollisions: true),
        throwsArgumentError);
    expect(tokenResolver<AppEnv>({})(''), isNull);
    expect(
        tokenResolver({'a': AppEnv.dev, ' A ': AppEnv.dev},
            strictCollisions: true)(' a '),
        AppEnv.dev);
  });
}
