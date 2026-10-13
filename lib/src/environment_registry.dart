/// Holds the mapping between an environment key and its configuration.
///
/// Generic over:
/// - [K]: your environment key type, e.g. `AppEnvironment` or `String`
/// - [C]: your configuration class/type, e.g. `EnvironmentConfig`
///
/// Missing lookups can fall back to the default. Factory exceptions propagate.
/// Optional caching shares in-flight requests and retains successful values.
class EnvironmentRegistry<K, C> {
  final Map<K, Future<C> Function()> _configs;

  /// The environment to fall back to when resolution fails.
  final K defaultEnvironment;

  final bool _cacheEnabled;
  final bool _strict;
  final Map<K, Future<C>> _cache = {};

  /// Creates a registry. Strict mode requires a registered default environment.
  EnvironmentRegistry({
    required Map<K, Future<C> Function()> configs,
    required this.defaultEnvironment,
    bool cache = false,
    bool strict = false,
  })  : _configs = Map.unmodifiable(configs),
        _cacheEnabled = cache,
        _strict = strict {
    if (strict && !configs.containsKey(defaultEnvironment)) {
      throw StateError('Default environment is not registered.');
    }
  }

  /// Clears successful and in-flight cached entries without canceling callers.
  void clearCache() => _cache.clear();

  /// Returns the configuration for [env] or `null` if missing.
  Future<C>? tryGet(K env) {
    final factory = _configs[env];
    if (factory == null) return null;
    if (!_cacheEnabled) return factory();
    final cached = _cache[env];
    if (cached != null) return cached;
    late final Future<C> pending;
    pending = Future<C>.sync(factory).then((value) => value,
        onError: (Object error, StackTrace stack) {
      if (identical(_cache[env], pending)) _cache.remove(env);
      Error.throwWithStackTrace(error, stack);
    });
    _cache[env] = pending;
    return pending;
  }

  /// Returns the configuration for [env], or the default configuration if
  /// the requested one is missing. May still be `null` if neither exists.
  Future<C>? tryGetOrDefault(K env) {
    final hit = tryGet(env);
    if (hit != null) return hit;
    if (_strict) throw StateError('Environment is not registered.');
    return getDefault();
  }

  /// Returns the default configuration or `null` if it wasn't provided.
  Future<C>? getDefault() => tryGet(defaultEnvironment);

  /// Returns the set of supported environments in this registry.
  Iterable<K> supportedEnvironments() => _configs.keys;
}
