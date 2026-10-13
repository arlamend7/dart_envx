import 'dart:convert';
import 'dart:io';

import '../config/config_exception.dart';
import '../config/config_source.dart';
import '../config/environment_values.dart';
import '../parsers/dotenv_parser.dart';
import '../parsers/json_config_parser.dart';

Future<String?> _readFile(String path, bool optional) async {
  final file = File(path);
  try {
    return utf8.decode(await file.readAsBytes());
  } on FileSystemException catch (error) {
    // ENOENT on POSIX, ERROR_FILE_NOT_FOUND / PATH_NOT_FOUND on Windows.
    final code = error.osError?.errorCode;
    final missing = code == 2 || (Platform.isWindows && code == 3);
    if (optional && missing) return null;
    throw ConfigSourceException(missing
        ? 'Required configuration file is missing.'
        : 'Configuration file could not be read.');
  } on FormatException {
    throw const ConfigParseException('Configuration file is not valid UTF-8.');
  }
}

/// A native UTF-8 JSON-object file loaded on demand.
class JsonFileSource implements ConfigSource {
  /// Resolves [path] to an absolute path at construction.
  ///
  /// [optional] permits only missing files, never invalid or unreadable files.
  JsonFileSource(String path, {this.optional = false})
      : path = File(path).absolute.path;

  /// Absolute file path captured at construction.
  final String path;

  /// Whether an absent file produces an empty source.
  final bool optional;

  @override
  Future<Map<String, Object?>> load() async {
    final text = await _readFile(path, optional);
    return text == null ? const {} : parseJsonConfig(text);
  }
}

/// A native dotenv file with optional prefix filtering and nested keys.
class DotEnvFileSource implements ConfigSource {
  /// Resolves [path] at construction; [optional] permits only missing files.
  DotEnvFileSource(
    String path, {
    this.optional = false,
    this.prefix = '',
    this.separator = '__',
  }) : path = File(path).absolute.path {
    if (separator.isEmpty) throw ArgumentError('Separator must not be empty.');
  }

  /// Absolute file path captured at construction.
  final String path;

  /// Whether an absent file produces an empty source.
  final bool optional;

  /// Exact prefix removed from matching keys.
  final String prefix;

  /// Separator used to turn flat keys into nested objects.
  final String separator;

  @override
  Future<Map<String, Object?>> load() async {
    final text = await _readFile(path, optional);
    return text == null
        ? const {}
        : nestEnvironmentValues(
            parseDotEnv(text),
            prefix: prefix,
            separator: separator,
          );
  }
}
