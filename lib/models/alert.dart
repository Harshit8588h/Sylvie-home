import 'family_member.dart';

enum AlertType {
  zoneExit,
  zoneEnter,
  batteryLow,
  phoneOffline,
  sos,
}

class FamilyAlert {
  final String id;
  final String memberId;
  final AlertType type;
  final DateTime timestamp;
  final LatLng? location;
  final String? zoneId;
  final String? zoneName;
  final List<String> acknowledgedBy;
  final bool resolved;
  final String? note;

  const FamilyAlert({
    required this.id,
    required this.memberId,
    required this.type,
    required this.timestamp,
    this.location,
    this.zoneId,
    this.zoneName,
    this.acknowledgedBy = const [],
    this.resolved = false,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'member_id': memberId,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'location': location?.toJson(),
        'zone_id': zoneId,
        'zone_name': zoneName,
        'acknowledged_by': acknowledgedBy,
        'resolved': resolved,
        'note': note,
      };

  factory FamilyAlert.fromJson(Map<String, dynamic> j) => FamilyAlert(
        id: j['id'] as String,
        memberId: j['member_id'] as String,
        type: AlertType.values.byName(j['type'] as String),
        timestamp: DateTime.parse(j['timestamp'] as String),
        location: j['location'] == null
            ? null
            : LatLng.fromJson(j['location'] as Map<String, dynamic>),
        zoneId: j['zone_id'] as String?,
        zoneName: j['zone_name'] as String?,
        acknowledgedBy: ((j['acknowledged_by'] as List?) ?? []).cast<String>(),
        resolved: j['resolved'] as bool? ?? false,
        note: j['note'] as String?,
      );
}
