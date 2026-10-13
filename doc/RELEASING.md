# Release validation

Version **2.0.0** is the stable release, dated **2026-10-12**. The changelog,
public documentation, and package metadata describe that release. Publication
to pub.dev and GitHub tags are separate distribution steps; the validation
commands below do not publish the package.

See [VALIDATION.md](VALIDATION.md) for the measured results for this checkout.

## Local checks

```sh
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
dart run example/minimal_example.dart
dart run example/envx_example.dart
dart run -DAPP_ENV=production example/envx_example.dart
dart run example/configuration_example.dart
dart compile exe -DAPP_ENV=prod -DCUSTOM_ENV=prod tool/compile_smoke.dart -o /tmp/envx-smoke
/tmp/envx-smoke
dart compile js -DAPP_ENV=prod -DCUSTOM_ENV=prod tool/compile_smoke.dart -o /tmp/envx-smoke.js
dart doc
dart pub publish --dry-run
dart pub global activate pana
dart pub global run pana --exit-code-threshold 0 .
```

The JavaScript compile verifies the core entry point has no native dependency.
The AOT run verifies fixed `APP_ENV` and custom const injection. Native adapters
are tested on Linux, macOS, and Windows in CI. Minimum Dart 3.0 resolves an
SDK-compatible set of development dependencies; current stable resolves newer
compatible versions. Do not commit a library dependency lockfile.

## 160/160 target

PANA/pub.dev awards points based on actual analysis and package contents, not a
pubspec flag. Keep public APIs documented, links live, examples accurate, license
recognized, dependencies compatible, and all checks passing. CI runs PANA and
requires the machine-readable score to equal the available maximum of 160.
Network/platform/tooling failures must be reported rather than represented as a
perfect score. Pub.dev recomputes its own score after publication and can differ
from a local run as SDKs, dependencies, and scoring rules change.

The API documentation URL in pubspec points to the GitHub Pages root. The docs
workflow deploys generated Dartdoc there on `main`. This checkout's updated
reference becomes public only after that workflow runs.
