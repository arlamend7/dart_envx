import 'dart:io';

import '../config/config_source.dart';
import '../config/environment_values.dart';

/// Native process environment strings, optionally filtered and nested.
///
/// This is unrelated to compiler defines and is not a live OS subscription.
class PlatformEnvironmentSource implements ConfigSource {
  /// Uses [Platform.environment] unless a test/application [environment] is given.
  PlatformEnvironmentSource({
    this.prefix = '',
    this.separator = '__',
    Map<String, String>? environment,
  }) : _environment =
            environment == null ? null : Map.unmodifiable(environment) {
    if (separator.isEmpty) throw ArgumentError('Separator must not be empty.');
  }

  /// Case-sensitive prefix to filter and strip.
  final String prefix;

  /// Nested key separator; defaults to a double underscore.
  final String separator;
  final Map<String, String>? _environment;

  @override
  Future<Map<String, Object?>> load() async => nestEnvironmentValues(
        _environment ?? Platform.environment,
        prefix: prefix,
        separator: separator,
      );
}
