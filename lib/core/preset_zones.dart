import '../models/family_member.dart';

/// Known locations the family visits often. Users can turn these into
/// safe zones with one tap during onboarding instead of searching the map.
class PresetZone {
  final String key;
  final String displayName;
  final LatLng center;
  final double suggestedRadiusMeters;

  const PresetZone({
    required this.key,
    required this.displayName,
    required this.center,
    required this.suggestedRadiusMeters,
  });
}

const List<PresetZone> presetZones = [
  PresetZone(
    key: 'aiims_delhi',
    displayName: 'AIIMS Delhi',
    center: LatLng(28.5672, 77.2100),
    suggestedRadiusMeters: 300,
  ),
];
