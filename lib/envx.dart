/// Layered configuration and typed environment selection for Dart and Flutter.
///
/// Use [EnvxBuilder] for providers or [Environment] for environment factories.
/// Native filesystem/process providers are available in `envx_io.dart`.
library;

export 'src/default_resolvers.dart';
export 'src/types.dart';
export 'src/config/config_builder.dart';
export 'src/config/config_exception.dart';
export 'src/config/config_source.dart';
export 'src/config/config_values.dart' show ConfigValues;
export 'src/config/environment_values.dart';
export 'src/parsers/json_config_parser.dart';
export 'src/parsers/dotenv_parser.dart';

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

  /// Resolves explicit environment input or the compile-time define.
  ///
  /// Missing keys fall back to the default unless strict mode is enabled.
  /// Returns `null` only when both configurations are absent. Factory failures
  /// propagate. There is no cancellation of pending factories.
  Future<C>? current() {
    final env = _service.resolveFromBuildDefine();
    return _service.configFor(env);
  }

  /// Clears cached factories; the next read starts a fresh load.
  ///
  /// Already returned futures still complete for their original callers.
  void clearCache() => _service.registry.clearCache();

  /// Returns the key resolved from explicit input or the compile-time define.
  K currentKey() => _service.resolveFromBuildDefine();

  /// Resolve [raw] via the resolver and return its configuration.
  ///
  /// Unknown input or missing keys fall back to the default configuration.
  /// Returns `null` only if both requested and default configurations are absent.
  /// Resolver and factory exceptions propagate.
  Future<C>? getEnvironment(String raw) => _service.configFromString(raw);

  /// Directly fetch configuration for [env].
  ///
  /// Missing keys fall back to the default; returns `null` if both are absent.
  /// Strict instances throw instead of falling back.
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
  /// - [environment]: a value read at a const call site in the application.
  ///   When omitted, the fixed `APP_ENV` const declaration is used.
  /// - [cache]: opt-in per-key factory caching, including in-flight requests.
  ///   Failed futures are evicted and can be retried.
  /// - [strict]: rejects unknown or missing environments instead of falling back.
  /// - [defineKey]: legacy dynamic key. Custom keys are not portable to AOT;
  ///   pass [environment] instead. The default `APP_ENV` key is reliable.
  static EnvironmentInstance<K, C> register<K, C>({
    required Map<K, Future<C> Function()> configuration,
    required K defaultEnvironment,
    EnvResolver<K>? resolver,
    @Deprecated(
        'Pass environment: const String.fromEnvironment("YOUR_KEY") instead.')
    String defineKey = EnvxConstants.defaultDefineKey,
    String? environment,
    bool cache = false,
    bool strict = false,
  }) {
    var res = resolver;
    if (res == null && K != String) {
      throw ArgumentError('Resolver is required for non-string environments.');
    } else if (res == null && K == String) {
      res = (input) => input as K?;
    }

    final registry = EnvironmentRegistry<K, C>(
      configs: configuration,
      defaultEnvironment: defaultEnvironment,
      cache: cache,
      strict: strict,
    );

    final service = EnvironmentService<K, C>(
      registry: registry,
      resolver: res!,
      defineKey: defineKey,
      environment: environment,
      strict: strict,
    );

    return EnvironmentInstance._(service);
  }
}
