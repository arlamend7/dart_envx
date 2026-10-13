import '../config/config_builder.dart';
import 'file_sources.dart';
import 'platform_environment_source.dart';

/// Native-only fluent providers. Import `package:envx/envx_io.dart`.
extension EnvxIoBuilder on EnvxBuilder {
  /// Adds a UTF-8 JSON-object file; optional means missing files only.
  EnvxBuilder addJsonFile(String path, {bool optional = false}) =>
      addSource(JsonFileSource(path, optional: optional));

  /// Adds a dotenv file, preserving strings until typed access or binding.
  EnvxBuilder addDotEnvFile(
    String path, {
    bool optional = false,
    String prefix = '',
    String separator = '__',
  }) =>
      addSource(DotEnvFileSource(path,
          optional: optional, prefix: prefix, separator: separator));

  /// Adds native process values; use a prefix to limit included variables.
  EnvxBuilder addEnvironmentVariables({
    String prefix = '',
    String separator = '__',
    Map<String, String>? environment,
  }) =>
      addSource(PlatformEnvironmentSource(
          prefix: prefix, separator: separator, environment: environment));
}
