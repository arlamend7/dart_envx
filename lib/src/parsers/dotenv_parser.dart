import '../config/config_exception.dart';

/// Parses dotenv assignments into strings without interpolation or evaluation.
///
/// Supports blank lines, comments, `export`, empty values, literal single
/// quotes, and double quotes with `\n`, `\r`, `\t`, `\\`, and `\"` escapes.
/// Unquoted inline comments require whitespace before `#`. Quoted values must
/// fit on one line; trailing content must be a comment. Duplicate keys use the
/// last assignment. Keys match `[A-Za-z_][A-Za-z0-9_]*` and are case-sensitive.
Map<String, String> parseDotEnv(String text) {
  final values = <String, String>{};
  final lines = text.replaceFirst(RegExp(r'^\uFEFF'), '').split('\n');
  for (var index = 0; index < lines.length; index++) {
    var line = lines[index].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trimLeft();
    final equals = line.indexOf('=');
    Never invalid() => throw ConfigParseException(
        'Invalid dotenv syntax on line ${index + 1}.');
    if (equals < 1) invalid();
    final key = line.substring(0, equals).trim();
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) invalid();
    final raw = line.substring(equals + 1).trimLeft();
    if (raw.startsWith('"') || raw.startsWith("'")) {
      final quote = raw[0];
      final value = StringBuffer();
      var closed = false;
      for (var i = 1; i < raw.length; i++) {
        final char = raw[i];
        if (char == quote) {
          final rest = raw.substring(i + 1).trimLeft();
          if (rest.isNotEmpty && !rest.startsWith('#')) invalid();
          closed = true;
          break;
        }
        if (quote == '"' && char == r'\') {
          if (++i >= raw.length) invalid();
          switch (raw[i]) {
            case 'n':
              value.write('\n');
            case 'r':
              value.write('\r');
            case 't':
              value.write('\t');
            case r'\':
              value.write(r'\');
            case '"':
              value.write('"');
            default:
              invalid();
          }
        } else {
          value.write(char);
        }
      }
      if (!closed) invalid();
      values[key] = value.toString();
    } else {
      final comment = RegExp(r'(^|\s)#').firstMatch(raw);
      values[key] =
          (comment == null ? raw : raw.substring(0, comment.start)).trimRight();
    }
  }
  return Map.unmodifiable(values);
}
