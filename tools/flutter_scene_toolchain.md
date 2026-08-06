# Padlo `flutter_scene` toolchain

The Padlo pilot is deliberately isolated from the repository's stable Flutter
checks. `flutter_scene` is pinned exactly to `0.20.0` and currently requires a
Flutter master engine newer than the global stable installation.

- FVM configuration: [`.fvmrc`](../.fvmrc) (FVM commit key `8ebfb2e4910`)
- Resolved local revision: `8ebfb2e491`
- Resolved version: `Flutter 3.47.0-1.0.pre-396`
- Dart: `3.14.0`

FVM 3.2.1 installs the commit directly, so CI and local development use the
same immutable engine revision. When the pilot is deliberately upgraded,
update `.fvmrc` and this file together, then rerun the Padlo format, analysis,
test, Chrome integration, and release-web gates.

Enable the two asset systems once per FVM SDK:

```powershell
fvm flutter config --enable-native-assets --enable-dart-data-assets
```

The stable job intentionally validates the reusable `scroll_world` package and
Kenya example separately, without resolving the Padlo-only dependency.
