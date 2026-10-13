/// A configuration failure with a safe, value-free diagnostic message.
class ConfigException implements Exception {
  /// Creates an exception. Avoid including secrets in [message].
  const ConfigException(this.message);

  /// A description of the failure, without configuration values.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// A required configuration source could not be read.
class ConfigSourceException extends ConfigException {
  /// Creates a source failure without exposing the underlying file contents.
  const ConfigSourceException(super.message);
}

/// Configuration text has invalid syntax or a non-object JSON root.
class ConfigParseException extends ConfigException {
  /// Creates a parsing failure with safe positional context.
  const ConfigParseException(super.message);
}

/// A required path was absent or contained null.
class ConfigMissingException extends ConfigException {
  /// Creates a missing-value failure.
  const ConfigMissingException(super.message);
}

/// A configuration value could not be converted to the requested type.
class ConfigTypeException extends ConfigException {
  /// Creates a conversion failure without disclosing the value.
  const ConfigTypeException(super.message);
}

/// A caller's model binder failed.
class ConfigBindingException extends ConfigException {
  /// Creates a binding failure.
  const ConfigBindingException(super.message);
}

/// Configuration did not satisfy application validation rules.
class ConfigValidationException extends ConfigException {
  /// Creates a validation failure. Keep custom messages free of secrets.
  const ConfigValidationException(super.message);
}
