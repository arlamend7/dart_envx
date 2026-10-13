import 'config_exception.dart';
import 'config_source.dart';
import 'config_values.dart';

/// Loads ordered sources into immutable values or a validated application model.
///
/// Builders are reusable. Each completed build is independent; concurrent
/// builds on the same source list share source loading. Binding and validation
/// run separately for each caller. Adding a source affects subsequent builds.
class EnvxBuilder {
  /// Creates an empty builder; add sources in increasing precedence order.
  EnvxBuilder();

  final List<ConfigSource> _sources = [];
  Future<Map<String, Object?>>? _pending;

  /// Appends [source], giving it precedence over previously registered sources.
  EnvxBuilder addSource(ConfigSource source) {
    _sources.add(source);
    _pending = null;
    return this;
  }

  /// Appends immutable in-memory defaults or overrides.
  EnvxBuilder addMemory(Map<String, Object?> values) =>
      addSource(MemoryConfigSource(values));

  Future<Map<String, Object?>> _load() {
    final pending = _pending;
    if (pending != null) return pending;
    final sources = List<ConfigSource>.of(_sources);
    late final Future<Map<String, Object?>> operation;
    operation = (() async {
      var values = <String, Object?>{};
      for (final source in sources) {
        values = mergeConfig(values, await source.load());
      }
      return freezeConfig(values);
    })()
        .whenComplete(() {
      if (identical(_pending, operation)) _pending = null;
    });
    return _pending = operation;
  }

  /// Loads immutable values with primitive and section getters.
  Future<ConfigValues> buildValues() async => ConfigValues(await _load());

  /// Loads and binds a model, then validates it before returning.
  ///
  /// The binder receives a deeply immutable map. Models should also be
  /// immutable. Binder failures are redacted; custom [ConfigValidationException]
  /// messages are preserved. Other validator exceptions are redacted.
  Future<T> build<T>(
    T Function(Map<String, Object?> values) bind, {
    void Function(T value)? validate,
  }) async {
    final values = await _load();
    final T model;
    try {
      model = bind(values);
    } catch (_) {
      throw const ConfigBindingException('Unable to bind configuration model.');
    }
    try {
      validate?.call(model);
    } on ConfigValidationException {
      rethrow;
    } catch (_) {
      throw const ConfigValidationException('Configuration validation failed.');
    }
    return model;
  }
}
