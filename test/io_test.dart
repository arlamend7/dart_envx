@TestOn('vm')
library;

import 'dart:io';
import 'package:envx/envx_io.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporary;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('envx-test-');
  });
  tearDown(() async {
    await temporary.delete(recursive: true);
  });
  String path(String name) => '${temporary.path}/$name';

  test('files compose with dotenv and process overrides', () async {
    await File(path('base.json'))
        .writeAsString('{"api":{"url":"base","timeout":30}}');
    await File(path('.env')).writeAsString('APP__api__timeout=15');
    final config = await EnvxBuilder()
        .addJsonFile(path('base.json'))
        .addDotEnvFile(path('.env'), prefix: 'APP__')
        .addEnvironmentVariables(
            prefix: 'APP__',
            environment: {'APP__api__url': 'process'}).buildValues();
    expect(config.getString('api.url'), 'process');
    expect(config.getInt('api.timeout'), 15);
  });

  test('optional permits only missing files', () async {
    expect(
        await JsonFileSource(path('absent/base.json'), optional: true).load(),
        isEmpty);
    expect(await DotEnvFileSource(path('absent.env'), optional: true).load(),
        isEmpty);
    await expectLater(JsonFileSource(path('absent.json')).load(),
        throwsA(isA<ConfigSourceException>()));
    await expectLater(DotEnvFileSource(path('absent.env')).load(),
        throwsA(isA<ConfigSourceException>()));
    await File(path('bad.json')).writeAsString('secret-invalid');
    await File(path('bad.env')).writeAsString('secret-invalid');
    await expectLater(JsonFileSource(path('bad.json'), optional: true).load(),
        throwsA(isA<ConfigParseException>()));
    await expectLater(DotEnvFileSource(path('bad.env'), optional: true).load(),
        throwsA(isA<ConfigParseException>()));
    await expectLater(JsonFileSource(temporary.path, optional: true).load(),
        throwsA(isA<ConfigSourceException>()));
  });

  test('invalid UTF-8 remains an error for optional files', () async {
    await File(path('bad.json')).writeAsBytes([0xff, 0xfe]);
    await expectLater(JsonFileSource(path('bad.json'), optional: true).load(),
        throwsA(isA<ConfigParseException>()));
  });

  test('rebuild sees creation, replacement and removal', () async {
    final builder = EnvxBuilder().addMemory({'value': 0}).addSource(
        JsonFileSource(path('settings.json'), optional: true));
    expect((await builder.buildValues()).getInt('value'), 0);
    await File(path('settings.json')).writeAsString('{"value":1}');
    expect((await builder.buildValues()).getInt('value'), 1);
    await File(path('new.json')).writeAsString('{"value":2}');
    await File(path('new.json')).rename(path('settings.json'));
    expect((await builder.buildValues()).getInt('value'), 2);
    await File(path('settings.json')).delete();
    expect((await builder.buildValues()).getInt('value'), 0);
  });

  test('injected process maps are copied and real process can load', () async {
    final input = {'APP__port': '80'};
    final source =
        PlatformEnvironmentSource(prefix: 'APP__', environment: input);
    input['APP__port'] = '90';
    expect(await source.load(), {'port': '80'});
    expect(
        await PlatformEnvironmentSource(prefix: 'ENVX_TEST_UNLIKELY_MISSING__')
            .load(),
        isEmpty);
  });
}
