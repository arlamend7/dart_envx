// Public entry points for the envx environment resolver.
//
// Provides the [Environment] factory to configure and query typed
// environments without relying on global state.

export 'src/default_resolvers.dart';
export 'src/types.dart';

import 'src/environment_registry.dart';
import 'src/environment_service.dart';
import 'src/types.dart';

/// Creates typed environments and exposes configuration lookups.
///
/// Generic over:
/// - [K]: environment key type, e.g. `AppEnvironment` or `String`.
/// - [C]: configuration type, e.g. `AppConfig`.
class Environment<K, C> {
  Environment._(this._service);

  /// Factory to build an [Environment] instance.
  ///
  /// Parameters:
  /// - [configs]: mapping from environment keys to async configuration builders.
  ///   May be empty; lookups will then yield `null`.
  /// - [defaultEnvironment]: used when resolution fails.
  /// - [resolver]: optional function translating a raw string to a key.
  ///   When omitted and [K] is `String`, an identity resolver is used.
  ///   For other types without a resolver, unknown values fall back to
  ///   [defaultEnvironment].
  /// - [defineKey]: compile-time define key. Defaults to
  ///   [EnvxConstants.defaultDefineKey].
  factory Environment({
    required Map<K, Future<C> Function()> configs,
    required K defaultEnvironment,
    EnvResolver<K>? resolver,
    String defineKey = EnvxConstants.defaultDefineKey,
  }) {
    final registry = EnvironmentRegistry<K, C>(
      configs: configs,
      defaultEnvironment: defaultEnvironment,
    );

    EnvResolver<K> effectiveResolver;
    if (resolver != null) {
      effectiveResolver = resolver;
    } else if (K == String) {
      effectiveResolver = (input) => input as K;
    } else {
      effectiveResolver = (_) => null;
    }

    final service = EnvironmentService<K, C>(
      registry: registry,
      resolver: effectiveResolver,
      defineKey: defineKey,
    );

    return Environment._(service);
  }

  final EnvironmentService<K, C> _service;

  /// Resolve the current environment from the build define and return its
  /// configuration.
  ///
  /// [fallbackValue] provides a value when the define is empty, useful for
  /// tests or platforms without `--dart-define` support.
  ///
  /// No cancellation token: configuration builders are expected to complete
  /// quickly and cannot be cancelled.
  Future<C>? current({String? fallbackValue}) {
    final env = _service.resolveFromBuildDefine(fallbackValue: fallbackValue);
    return _service.configFor(env);
  }

  /// Returns the environment key resolved from the build define.
  K currentKey({String? fallbackValue}) =>
      _service.resolveFromBuildDefine(fallbackValue: fallbackValue);

  /// Resolve [raw] via the resolver and return its configuration.
  Future<C>? getEnvironment(String raw) => _service.configFromString(raw);

  /// Directly fetch configuration for [env].
  Future<C>? getEnvironmentByKey(K env) => _service.configFor(env);
}
