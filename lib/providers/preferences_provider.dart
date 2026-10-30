import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences for first-run flags, trip mode,
/// active-group choice, and other per-device settings. Everything surfaced
/// through Riverpod so screens can react to changes without manually
/// threading callbacks.

const _kBatterySetupDone = 'battery_setup_done';
const _kActiveGroupId = 'active_group_id';
const _kHasSignedInBefore = 'has_signed_in_before';

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

/// The group id the user currently has open. Persisted per-device so a
/// re-launch returns to the same group. null = either not loaded yet or
/// no explicit choice (callers fall back to the first known membership).
class ActiveGroupController extends StateNotifier<String?> {
  final Ref _ref;
  ActiveGroupController(this._ref) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await _ref.read(sharedPrefsProvider.future);
    state = prefs.getString(_kActiveGroupId);
  }

  Future<void> set(String? id) async {
    final prefs = await _ref.read(sharedPrefsProvider.future);
    if (id == null) {
      await prefs.remove(_kActiveGroupId);
    } else {
      await prefs.setString(_kActiveGroupId, id);
    }
    state = id;
  }
}

final activeGroupPrefProvider =
    StateNotifierProvider<ActiveGroupController, String?>(
  (ref) => ActiveGroupController(ref),
);

/// Tiny helper read synchronously at app start: tells the auth gate
/// whether we expect a user to be restored, so it can keep showing the
/// spinner (instead of flashing sign-in) for the time it takes Firebase
/// to read its cache. Set true on successful OTP verify, false on
/// explicit sign-out.
class HasSignedInBeforeController extends StateNotifier<bool> {
  final Ref _ref;
  HasSignedInBeforeController(this._ref) : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await _ref.read(sharedPrefsProvider.future);
    state = prefs.getBool(_kHasSignedInBefore) ?? false;
  }

  Future<void> set(bool value) async {
    final prefs = await _ref.read(sharedPrefsProvider.future);
    await prefs.setBool(_kHasSignedInBefore, value);
    state = value;
  }
}

final hasSignedInBeforeProvider =
    StateNotifierProvider<HasSignedInBeforeController, bool>(
  (ref) => HasSignedInBeforeController(ref),
);
