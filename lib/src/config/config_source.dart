import 'config_values.dart';

/// An asynchronous provider of JSON-compatible configuration values.
///
/// Each load returns a complete source snapshot. Implementations must report
/// malformed content and required-source failures, not silently return defaults.
abstract interface class ConfigSource {
  /// Loads this source; later registered sources override earlier ones.
  Future<Map<String, Object?>> load();
}

/// Immutable defaults or explicit overrides available on every platform.
class MemoryConfigSource implements ConfigSource {
  /// Copies and freezes input immediately, preventing caller mutation.
  MemoryConfigSource(Map<String, Object?> values)
      : _values = freezeConfig(values);

  final Map<String, Object?> _values;

  @override
  Future<Map<String, Object?>> load() async => _values;
}
