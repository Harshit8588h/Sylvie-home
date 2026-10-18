import 'family_member.dart';

class SafeZone {
  final String id;
  final String name;
  final LatLng center;
  final double radiusMeters;
  /// Member ids this zone applies to. Empty = applies to everyone.
  final List<String> appliesTo;
  final bool alertOnExit;
  final bool alertOnEnter;
  final bool active;
  final DateTime createdAt;

  const SafeZone({
    required this.id,
    required this.name,
    required this.center,
    required this.radiusMeters,
    required this.appliesTo,
    required this.createdAt,
    this.alertOnExit = true,
    this.alertOnEnter = false,
    this.active = true,
  });

  bool appliesToMember(String memberId) =>
      appliesTo.isEmpty || appliesTo.contains(memberId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'center': center.toJson(),
        'radius_m': radiusMeters,
        'applies_to': appliesTo,
        'alert_on_exit': alertOnExit,
        'alert_on_enter': alertOnEnter,
        'active': active,
        'created_at': createdAt.toIso8601String(),
      };

  factory SafeZone.fromJson(Map<String, dynamic> j) => SafeZone(
        id: j['id'] as String,
        name: j['name'] as String,
        center: LatLng.fromJson(j['center'] as Map<String, dynamic>),
        radiusMeters: (j['radius_m'] as num).toDouble(),
        appliesTo: (j['applies_to'] as List).cast<String>(),
        alertOnExit: j['alert_on_exit'] as bool? ?? true,
        alertOnEnter: j['alert_on_enter'] as bool? ?? false,
        active: j['active'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
