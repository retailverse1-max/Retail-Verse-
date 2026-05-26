import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/pos_settings.dart';

/// Local persistence for [PosSettings]. Replace / extend with REST sync when backend is ready.
class SettingsRepository {
  SettingsRepository();

  static const _prefsKey = 'pos_app_settings_json_v1';

  Future<PosSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return PosSettings.defaults();
    }
    return PosSettings.decode(raw);
  }

  Future<void> save(PosSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, settings.encode());
  }

  /// For future: POST /api/settings with [PosSettings.toJson].
  Future<void> pushToBackend(PosSettings settings) async {
    // TODO: implement when API exists
    await save(settings);
  }
}
