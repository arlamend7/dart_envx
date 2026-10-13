import 'dart:async';
import 'package:envx/envx.dart';
import 'package:test/test.dart';

class CallbackSource implements ConfigSource {
  CallbackSource(this.callback);
  final Future<Map<String, Object?>> Function() callback;
  @override
  Future<Map<String, Object?>> load() => callback();
}

void main() {
  test('deep merge, replacement, case and defensive freezing', () async {
    final base = <String, Object?>{
      'api': {'url': 'base', 'timeout': 30},
      'items': [1, 2],
      'nullable': 1,
      'shape': {'old': true},
      'API': 2,
    };
    final builder = EnvxBuilder().addMemory(base).addMemory({
      'api': {'timeout': 10},
      'items': [3],
      'nullable': null,
      'shape': false,
    });
    (base['api'] as Map)['url'] = 'mutated';
    final config = await builder.buildValues();
    expect(config.values, {
      'api': {'url': 'base', 'timeout': 10},
      'items': [3],
      'nullable': null,
      'shape': false,
      'API': 2,
    });
    expect(
        () => (config.get('api') as Map)['url'] = 'x', throwsUnsupportedError);
    expect(() => (config.get('items') as List).add(4), throwsUnsupportedError);
    expect(() => config.values['new'] = 1, throwsUnsupportedError);
    final changed = await EnvxBuilder().addMemory({'api': 1}).addMemory({
      'api': {'value': 3}
    }).buildValues();
    expect(changed.getInt('api.value'), 3);
  });

  test('overlapping builds share only loading; later builds reload', () async {
    var calls = 0;
    final ready = Completer<Map<String, Object?>>();
    final builder = EnvxBuilder().addSource(CallbackSource(() {
      calls++;
      return ready.future;
    })).addMemory({'value': 2});
    final first = builder.buildValues();
    final second = builder.build((map) => map['value']);
    ready.complete({'value': 1});
    expect((await first).getInt('value'), 2);
    expect(await second, 2);
    expect(calls, 1);
    await builder.buildValues();
    expect(calls, 2);
  });

  test('source additions during a build apply only to later builds', () async {
    final ready = Completer<Map<String, Object?>>();
    final builder = EnvxBuilder().addSource(CallbackSource(() => ready.future));
    final first = builder.buildValues();
    builder.addMemory({'value': 2});
    final second = builder.buildValues();
    ready.complete({'value': 1});
    expect((await first).getInt('value'), 1);
    expect((await second).getInt('value'), 2);
  });

  test('failed shared loads can be retried', () async {
    var calls = 0;
    final builder = EnvxBuilder().addSource(CallbackSource(() async {
      if (++calls == 1) throw const ConfigSourceException('Unavailable.');
      return {'value': 1};
    }));
    final first = builder.buildValues();
    final second = builder.buildValues();
    await Future.wait([
      expectLater(first, throwsA(isA<ConfigSourceException>())),
      expectLater(second, throwsA(isA<ConfigSourceException>())),
    ]);
    expect((await builder.buildValues()).getInt('value'), 1);
  });

  test('empty builder; unsupported objects and nonfinite numbers', () async {
    expect((await EnvxBuilder().buildValues()).values, isEmpty);
    expect(() => MemoryConfigSource({'value': Object()}),
        throwsA(isA<ConfigTypeException>()));
    expect(() => MemoryConfigSource({'value': double.infinity}),
        throwsA(isA<ConfigTypeException>()));
  });

  test('typed paths, sections, escaping, and explicit null', () {
    final config = ConfigValues({
      'api': {'number': '12', 'bool': 'TRUE', 'double': '1.25'},
      'literal.dot': {r'back\slash': 'yes'},
      'nil': null,
    });
    expect(config.getInt('api.number'), 12);
    expect(config.getBool('api.bool'), isTrue);
    expect(config.getDouble('api.double'), 1.25);
    expect(config.getSection('api').getString('number'), '12');
    expect(config.getString(r'literal\.dot.back\\slash'), 'yes');
    expect(config.contains('nil'), isTrue);
    expect(config.contains('missing'), isFalse);
    expect(config.get('missing'), isNull);
    expect(
        () => config.getString('nil'), throwsA(isA<ConfigMissingException>()));
    expect(
        () => config.getInt('missing'), throwsA(isA<ConfigMissingException>()));
    expect(() => config.getString('api'), throwsA(isA<ConfigTypeException>()));
    for (final path in ['', '.api', 'api.', 'a..b', r'a\q', 'a\\']) {
      expect(() => config.get(path), throwsArgumentError);
    }
  });

  test('conversions reject ambiguous coercions and redact values', () {
    final config = ConfigValues({
      'float': 1.5,
      'bool': 'yes',
      'secret': 'token',
      'infinite': 'Infinity'
    });
    expect(() => config.getInt('float'), throwsA(isA<ConfigTypeException>()));
    expect(() => config.getBool('bool'), throwsA(isA<ConfigTypeException>()));
    expect(() => config.getDouble('infinite'),
        throwsA(isA<ConfigTypeException>()));
    expect(
        () => config.getSection('secret'), throwsA(isA<ConfigTypeException>()));
    expect(
        () => config.getInt('secret'),
        throwsA(isA<ConfigTypeException>().having(
            (e) => e.toString(), 'redaction', isNot(contains('token')))));
  });

  test('binding and validation precede returning the model', () async {
    final builder = EnvxBuilder().addMemory({'port': '8080'});
    final port = await builder.build((map) => ConfigValues(map).getInt('port'),
        validate: (port) {
      if (port < 1) throw const ConfigValidationException('Invalid port.');
    });
    expect(port, 8080);
    await expectLater(
        builder.build<int>((_) => throw StateError('secret token')),
        throwsA(isA<ConfigBindingException>().having((e) => e.toString(),
            'redaction', isNot(contains('secret token')))));
    await expectLater(
        builder.build((_) => 0,
            validate: (_) => throw StateError('secret token')),
        throwsA(isA<ConfigValidationException>().having((e) => e.toString(),
            'redaction', isNot(contains('secret token')))));
    await expectLater(
        builder.build((_) => 0,
            validate: (_) =>
                throw const ConfigValidationException('Invalid port.')),
        throwsA(isA<ConfigValidationException>()
            .having((e) => e.message, 'message', 'Invalid port.')));
  });

  test('JSON objects, Unicode, non-objects and syntax failures', () {
    expect(
        parseJsonConfig(
            '{"greeting":"Olá 🌎", "items": [true, null]}')['greeting'],
        'Olá 🌎');
    for (final text in [
      '[]',
      'null',
      '1',
      '"secret"',
      '{"password":"secret"'
    ]) {
      expect(
          () => parseJsonConfig(text),
          throwsA(isA<ConfigParseException>().having(
              (e) => e.toString(), 'redacted', isNot(contains('secret')))));
    }
  });

  test('dotenv quotes, escapes, comments, export and literal interpolation',
      () {
    final values = parseDotEnv(r'''
# comment
export NAME = café
EMPTY=
PLAIN=hello world # comment
HASH=hello#world
SINGLE='literal ${NAME} \n # hash'
DOUBLE="line\nnext\t\"quoted\"\\end" # comment
NAME=final
''');
    expect(values, {
      'NAME': 'final',
      'EMPTY': '',
      'PLAIN': 'hello world',
      'HASH': 'hello#world',
      'SINGLE': r'literal ${NAME} \n # hash',
      'DOUBLE': 'line\nnext\t"quoted"\\end',
    });
    expect(parseDotEnv('\uFEFFA=1\r\nB=2\r\n'), {'A': '1', 'B': '2'});
  });

  test('malformed dotenv reports line number without content', () {
    for (final text in [
      'invalid-secret',
      '=secret',
      '1A=secret',
      'A="secret',
      'A="secret"junk',
      r'A="secret\q"'
    ]) {
      expect(
          () => parseDotEnv(text),
          throwsA(isA<ConfigParseException>()
              .having((e) => e.message, 'redaction', isNot(contains('secret')))
              .having((e) => e.message, 'position', contains('line 1'))));
    }
  });

  test('environment keys preserve case and reject nesting collisions', () {
    expect(
        nestEnvironmentValues({
          'APP__api__BASE_URL': 'url',
          'APP__api__timeout': '10',
          'OTHER': 'ignored',
          'app__key': 'ignored',
        }, prefix: 'APP__'),
        {
          'api': {'BASE_URL': 'url', 'timeout': '10'}
        });
    expect(nestEnvironmentValues({'API': 'a', 'api': 'b'}),
        {'API': 'a', 'api': 'b'});
    for (final values in [
      {'APP__': '1'},
      {'APP__a____b': '1'},
      {'APP__a': '1', 'APP__a__b': '2'},
      {'APP__a__b': '1', 'APP__a': '2'},
    ]) {
      expect(() => nestEnvironmentValues(values, prefix: 'APP__'),
          throwsA(isA<ConfigParseException>()));
    }
    expect(() => nestEnvironmentValues({}, separator: ''), throwsArgumentError);
  });
}
