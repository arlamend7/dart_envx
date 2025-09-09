/// Provides compile-time environment configuration resolution.
///
/// Create an [Envx] instance with your own environment enum and configuration
/// class to retrieve environment-specific values at runtime.
///
/// This library contains only synchronous utilities, so a cancellation token is
/// unnecessary.
library;

export 'src/envx_base.dart' show Envx, EnvironmentResolver;
