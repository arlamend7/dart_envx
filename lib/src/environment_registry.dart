/// Holds the mapping between an environment key and its configuration.
///
/// Generic over:
/// - [K]: your environment key type, e.g. `AppEnvironment` or `String`
/// - [C]: your configuration class/type, e.g. `EnvironmentConfig`
///
/// This class never throws. When a lookup misses, it returns `null` or
/// falls back to the default config via `tryGetOrDefault`.
class EnvironmentRegistry<K, C> {
  final Map<K, Future<C> Function()> _configs;

  /// The environment to fall back to when resolution fails.
  final K defaultEnvironment;

  /// The default configuration (may be `null` if [defaultEnvironment] is not present in [configs]).
  final Future<C> Function()? _defaultConfig;

  /// Creates a registry. If [defaultEnvironment] is not present in [configs],
  /// `_defaultConfig` will be `null`, which means `tryGetOrDefault` returns `null`
  /// when both the requested and default configs are missing.
  const EnvironmentRegistry._(
    this._configs,
    this.defaultEnvironment,
    this._defaultConfig,
  );

  /// Factory with validation at the boundary; never throws.
  ///
  /// - If [configs] is empty, still returns a registry (all lookups become `null`).
  /// - If [defaultEnvironment] is absent in [configs], the registry stays valid,
  ///   but `getDefault()` will return `null`.
  factory EnvironmentRegistry({
    required Map<K, Future<C> Function()> configs,
    required K defaultEnvironment,
  }) {
    final defaultConfig = configs[defaultEnvironment];
    return EnvironmentRegistry._(
      Map.unmodifiable(configs),
      defaultEnvironment,
      defaultConfig,
    );
  }

  /// Returns the configuration for [env] or `null` if missing.
  Future<C>? tryGet(K env) {
    if (_configs.isEmpty) return null;
    return _configs[env]?.call();
  }

  /// Returns the configuration for [env], or the default configuration if
  /// the requested one is missing. May still be `null` if neither exists.
  Future<C>? tryGetOrDefault(K env) {
    final hit = tryGet(env);
    if (hit != null) return hit;
    return _defaultConfig?.call();
  }

  /// Returns the default configuration or `null` if it wasn't provided.
  Future<C>? getDefault() => _defaultConfig?.call();

  /// Returns the set of supported environments in this registry.
  Iterable<K> supportedEnvironments() => _configs.keys;
}
