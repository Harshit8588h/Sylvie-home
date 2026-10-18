import 'package:device_info_plus/device_info_plus.dart';

import '../models/family_member.dart';

/// Detects the phone's OEM at runtime so Sylvie can show the right
/// battery-setup guide. Grandma's exact Vivo model is unknown — this
/// handles every Vivo (and every other brand) without special-casing.
class OemDetector {
  final DeviceInfoPlugin _info;
  OemDetector({DeviceInfoPlugin? plugin}) : _info = plugin ?? DeviceInfoPlugin();

  Future<OemReport> detect() async {
    final a = await _info.androidInfo;
    final manufacturer = a.manufacturer.toLowerCase();
    final brand = a.brand.toLowerCase();
    final needle = '$manufacturer $brand';

    final oem = _match(needle);
    return OemReport(
      oem: oem,
      manufacturer: a.manufacturer,
      brand: a.brand,
      model: a.model,
      androidVersion: a.version.release,
      sdkInt: a.version.sdkInt,
    );
  }

  static PhoneOem _match(String s) {
    if (s.contains('vivo') || s.contains('iqoo')) return PhoneOem.vivo;
    if (s.contains('oppo')) return PhoneOem.oppo;
    if (s.contains('realme')) return PhoneOem.realme;
    if (s.contains('xiaomi') || s.contains('redmi') || s.contains('poco')) {
      return PhoneOem.xiaomi;
    }
    if (s.contains('samsung')) return PhoneOem.samsung;
    if (s.contains('oneplus')) return PhoneOem.oneplus;
    if (s.contains('google') || s.contains('pixel')) return PhoneOem.pixel;
    if (s.contains('motorola')) return PhoneOem.motorola;
    if (s.contains('nothing')) return PhoneOem.nothing;
    return PhoneOem.other;
  }
}

class OemReport {
  final PhoneOem oem;
  final String manufacturer;
  final String brand;
  final String model;
  final String androidVersion;
  final int sdkInt;

  const OemReport({
    required this.oem,
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.androidVersion,
    required this.sdkInt,
  });

  /// Phones known to be aggressive about killing background apps.
  /// These need the setup wizard; others can be skipped with a short warning.
  bool get isAggressiveKiller =>
      oem == PhoneOem.vivo ||
      oem == PhoneOem.oppo ||
      oem == PhoneOem.realme ||
      oem == PhoneOem.xiaomi;
}
