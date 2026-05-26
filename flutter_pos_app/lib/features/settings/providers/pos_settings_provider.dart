import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../domain/models/pos_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

class PosSettingsNotifier extends StateNotifier<PosSettings> {
  PosSettingsNotifier(this._repo) : super(PosSettings.defaults()) {
    _hydrate();
  }

  final SettingsRepository _repo;

  Future<void> _hydrate() async {
    final loaded = await _repo.load();
    state = loaded;
  }

  Future<void> refresh() async {
    state = await _repo.load();
  }

  Future<void> _persist(PosSettings next) async {
    state = next;
    await _repo.save(next);
  }

  Future<void> update(PosSettings Function(PosSettings current) fn) async {
    await _persist(fn(state));
  }

  Future<void> recordSuccessfulSync() async {
    await update(
      (s) => s.copyWith(
        lastSyncAtIso: DateTime.now().toIso8601String(),
      ),
    );
  }
}

final posSettingsProvider =
    StateNotifierProvider<PosSettingsNotifier, PosSettings>((ref) {
  return PosSettingsNotifier(ref.watch(settingsRepositoryProvider));
});
