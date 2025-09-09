/// Resolves a raw environment [value] into an enumeration instance.
///
/// Used by [Envx] to map the compile-time environment string into the
/// application's environment type.
typedef EnvironmentResolver<E extends Object> = E Function(String value);

/// Provides access to compile-time environment configuration.
///
/// Create an instance with your own environment enum and configuration class.
/// Retrieve the current configuration via [environment] or fetch a specific
/// one with [configFor].
///
/// The API is synchronous and holds no resources, therefore a cancellation
/// token is unnecessary.
class Envx<E extends Object, C extends Object> {
  /// Creates a new [Envx] store.
  ///
  /// [values] must contain at least one entry. The map is used to look up the
  /// configuration for a given environment. [resolver] translates the
  /// compile-time string into the environment enum.
  ///
  /// The [key] parameter specifies the compile-time variable name. It defaults
  /// to [defaultEnvironmentKey]. [defaultValue] is used when the compile-time
  /// variable is absent. It defaults to [defaultEnvironmentValue].
  const Envx({
    required Map<E, C> values,
    required EnvironmentResolver<E> resolver,
    String key = defaultEnvironmentKey,
    String defaultValue = defaultEnvironmentValue,
  }) : _values = values,
       _resolver = resolver,
       _key = key,
       _defaultValue = defaultValue;

  /// Name of the compile-time environment variable.
  static const String defaultEnvironmentKey = 'APP_ENV';

  /// Default value used when the compile-time variable is missing.
  static const String defaultEnvironmentValue = 'development';

  final Map<E, C> _values;
  final EnvironmentResolver<E> _resolver;
  final String _key;
  final String _defaultValue;

  /// Returns the environment constant derived from the compile-time define.
  E currentEnvironment() {
    final String raw = String.fromEnvironment(
      _key,
      defaultValue: _defaultValue,
    );
    return _resolver(raw);
  }

  /// Retrieves the configuration for [environment].
  ///
  /// Returns `null` when no configuration is registered for [environment].
  C? configFor(E environment) {
    return _values[environment];
  }

  /// Current configuration based on [currentEnvironment].
  C? get environment => configFor(currentEnvironment());
}
