import 'types.dart';
import 'environment_registry.dart';

/// Resolves the current environment and returns typed configuration.
///
/// Explicit values and a fixed const `APP_ENV` declaration support AOT builds.
/// Unknown values fall back unless strict mode is enabled; exceptions propagate.
class EnvironmentService<K, C> {
  /// Where we keep configs and the default environment.
  final EnvironmentRegistry<K, C> registry;

  /// How to parse a raw string value into the environment key.
  final EnvResolver<K> resolver;

  /// Compile-time define key, defaults to [EnvxConstants.defaultDefineKey].
  final String defineKey;

  /// Explicit compile-time value supplied by application code.
  final String? environment;

  /// Whether unknown or empty selection is rejected.
  final bool strict;

  /// Creates a new [EnvironmentService].
  ///
  /// Parameters:
  /// - [registry]: map of environments to configs, with a chosen default.
  /// - [resolver]: function that maps string => key (nullable result).
  /// - [defineKey]: optional override for the compile-time define key.
  const EnvironmentService({
    required this.registry,
    required this.resolver,
    this.defineKey = EnvxConstants.defaultDefineKey,
    this.environment,
    this.strict = false,
  });

  /// Parse [raw] via [resolver], falling back to [registry.defaultEnvironment] if null/empty/unrecognized.
  K resolveFromString(String? raw) {
    final trimmed = raw?.trim() ?? '';
    final resolved = trimmed.isEmpty ? null : resolver(trimmed);
    if (resolved == null && strict) {
      throw StateError('Environment selection is missing or unrecognized.');
    }
    return resolved ?? registry.defaultEnvironment;
  }

  /// Resolves explicit input or the fixed const `APP_ENV` declaration.
  ///
  /// Custom dynamic keys remain solely for 1.x compatibility and are not
  /// guaranteed outside JIT execution. Inject [environment] for portable builds.
  K resolveFromBuildDefine({String? key}) {
    if (environment != null) return resolveFromString(environment);
    final k = (key == null || key.isEmpty) ? defineKey : key;
    if (k == EnvxConstants.defaultDefineKey) {
      return resolveFromString(const String.fromEnvironment('APP_ENV'));
    }
    // Compatibility only: dynamic compiler lookups are not portable to AOT.
    return resolveFromString(
        String.fromEnvironment(k, defaultValue: defineKey));
  }

  /// Get configuration for [env] with fallback to default.
  ///
  /// May return `null` if neither the requested nor default configs exist in the registry.
  Future<C>? configFor(K env) => registry.tryGetOrDefault(env);

  /// Convenience: resolve environment from a string and return its config.
  Future<C>? configFromString(String? raw) {
    final env = resolveFromString(raw);
    return configFor(env);
  }

  /// Convenience: resolve environment from the build define and return its config.
  Future<C>? configFromBuildDefine({String? key}) {
    final env = resolveFromBuildDefine(key: key);
    return configFor(env);
  }
}
