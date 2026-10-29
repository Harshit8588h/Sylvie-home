import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences for first-run flags, trip mode,
/// and other per-device settings. Everything surfaced through Riverpod so
/// screens can react to changes without manually threading callbacks.

const _kBatterySetupDone = 'battery_setup_done';

final sharedPrefsProvider = FutureProvider<SharedPreferences>((_) async {
  return SharedPreferences.getInstance();
});

/// true once the user has run (or explicitly skipped) the OEM battery
/// setup wizard. Determines whether AuthGate shows the wizard on launch.
class BatterySetupController extends StateNotifier<bool> {
  final Ref _ref;
  BatterySetupController(this._ref) : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await _ref.read(sharedPrefsProvider.future);
    state = prefs.getBool(_kBatterySetupDone) ?? false;
  }

  Future<void> markDone() async {
    final prefs = await _ref.read(sharedPrefsProvider.future);
    await prefs.setBool(_kBatterySetupDone, true);
    state = true;
  }

  Future<void> reset() async {
    final prefs = await _ref.read(sharedPrefsProvider.future);
    await prefs.remove(_kBatterySetupDone);
    state = false;
  }
}

final batterySetupDoneProvider =
    StateNotifierProvider<BatterySetupController, bool>(
  (ref) => BatterySetupController(ref),
);
