/// Support for doing something awesome.
///
/// More dartdocs go here.
library;



// Read from compile-time define (e.g., --dart-define=APP_ENV=prod):
final currentEnvironment = env.resolveFromBuildDefine();               // -> AppEnvironment.production
final environment = env.configFromBuildDefine();                    // -> EnvironmentConfig for production