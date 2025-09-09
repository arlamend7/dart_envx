/// Signature for functions that map a raw environment string to an enum value.
///
/// Must return `null` if the input cannot be resolved.
/// Do **not** throw for control flow – envx will safely fall back.
typedef EnvResolver<E extends Enum> = E? Function(String input);

/// Constants used by the library. Keep magic strings out of the code.
abstract final class EnvxConstants {
  /// The default compile-time define key used to select the environment.
  static const String defaultDefineKey = 'APP_ENV';
}
