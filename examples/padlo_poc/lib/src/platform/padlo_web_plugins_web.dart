import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

/// Registers the web persistence backend before the store is first read.
///
/// Flutter normally invokes the generated registrant from the web entrypoint.
/// Keeping this explicit makes the standalone FVM/Chrome pilot resilient when
/// the app is launched from a workspace target or a hot-reload session.
void registerPadloWebPlugins() {
  SharedPreferencesPlugin.registerWith(webPluginRegistrar);
}
