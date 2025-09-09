// Public entry points for the envx environment resolver.
//
// Provides the [Environment] factory to configure and query typed or
// non-typed environments without relying on global state.

export 'src/default_resolvers.dart';
export 'src/types.dart';

import 'src/environment_registry.dart';
import 'src/environment_service.dart';
import 'src/types.dart';

/// Base environment wrapper used by both typed and non-typed variants.
///
/// Generic over:
/// - [K]: environment key type, e.g. `AppEnvironment` or `String`.
/// - [C]: configuration type, e.g. `AppConfig`.
class EnvironmentInstance<K, C> {
  const EnvironmentInstance._(this._service);

  final EnvironmentService<K, C> _service;

  /// Resolve the current environment from the build define and return its
  /// configuration.
  ///
  /// [fallbackValue] provides a value when the define is empty, useful for
  /// tests or platforms without `--dart-define` support.
  ///
  /// No cancellation token: configuration builders are expected to complete
  /// quickly and cannot be cancelled.
  Future<C>? current() {
    final env = _service.resolveFromBuildDefine();
    return _service.configFor(env);
  }

  /// Returns the environment key resolved from the build define.
  K currentKey() => _service.resolveFromBuildDefine();

  /// Resolve [raw] via the resolver and return its configuration.
  Future<C>? getEnvironment(String raw) => _service.configFromString(raw);

  /// Directly fetch configuration for [env].
  Future<C>? getEnvironmentByKey(K env) => _service.configFor(env);
}

/// Factory for creating typed or non-typed [EnvironmentInstance]s.
abstract final class Environment {
  /// Register an environment.
  ///
  /// Generic parameters [K] and [C] are typically inferred from
  /// [configuration] and [defaultEnvironment]; explicit type arguments are
  /// only needed for unusual cases.
  ///
  /// Parameters:
  /// - [configuration]: mapping from environment keys to async configuration
  ///   builders.
  /// - [defaultEnvironment]: key to use when resolution fails.
  /// - [resolver]: translation from raw strings to keys. Required for
  ///   non-string keys. When omitted and the key type is `String`, an identity
  ///   resolver is used.
  /// - [defineKey]: compile-time define key. Defaults to
  ///   [EnvxConstants.defaultDefineKey].
  static EnvironmentInstance<K, C> register<K, C>({
    required Map<K, Future<C> Function()> configuration,
    required K defaultEnvironment,
    EnvResolver<K>? resolver,
    String defineKey = EnvxConstants.defaultDefineKey,
  }) {
    var res = resolver;
    if (res == null && K != String) {
      throw ArgumentError('Resolver is required for non-string environments.');
    } else if (res == null && K == String) {
      res = (input) => input as K?;
    }

    final registry = EnvironmentRegistry<K, C>(configs: configuration, defaultEnvironment: defaultEnvironment);

    final service = EnvironmentService<K, C>(registry: registry, resolver: res!, defineKey: defineKey);

    return EnvironmentInstance._(service);
  }
}
