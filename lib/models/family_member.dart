enum FamilyRole { admin, member }

enum Relation { self, mother, father, sister, brother, grandmother, grandfather, other }

enum PhoneOem { vivo, oppo, xiaomi, realme, samsung, oneplus, pixel, motorola, nothing, other }

class LatLng {
  final double lat;
  final double lng;

  const LatLng(this.lat, this.lng);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
  factory LatLng.fromJson(Map<String, dynamic> j) =>
      LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());
}

class LastLocation {
  final LatLng position;
  final double accuracyMeters;
  final DateTime timestamp;
  final int batteryPercent;
  final bool isMoving;

  const LastLocation({
    required this.position,
    required this.accuracyMeters,
    required this.timestamp,
    required this.batteryPercent,
    required this.isMoving,
  });

  Map<String, dynamic> toJson() => {
        'position': position.toJson(),
        'accuracy_m': accuracyMeters,
        'timestamp': timestamp.toIso8601String(),
        'battery_percent': batteryPercent,
        'is_moving': isMoving,
      };

  factory LastLocation.fromJson(Map<String, dynamic> j) => LastLocation(
        position: LatLng.fromJson(j['position'] as Map<String, dynamic>),
        accuracyMeters: (j['accuracy_m'] as num).toDouble(),
        timestamp: DateTime.parse(j['timestamp'] as String),
        batteryPercent: j['battery_percent'] as int,
        isMoving: j['is_moving'] as bool,
      );
}

class FamilyMember {
  final String id;
  final String name;
  final FamilyRole role;
  final Relation relation;
  final String phoneNumber;
  final String? avatarUrl;
  final String? fcmToken;
  final PhoneOem phoneOem;
  final LastLocation? lastLocation;
  final bool isSharingLocation;
  final DateTime createdAt;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.role,
    required this.relation,
    required this.phoneNumber,
    required this.phoneOem,
    required this.createdAt,
    this.avatarUrl,
    this.fcmToken,
    this.lastLocation,
    this.isSharingLocation = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'relation': relation.name,
        'phone_number': phoneNumber,
        'avatar_url': avatarUrl,
        'fcm_token': fcmToken,
        'phone_oem': phoneOem.name,
        'last_location': lastLocation?.toJson(),
        'is_sharing_location': isSharingLocation,
        'created_at': createdAt.toIso8601String(),
      };

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
        id: j['id'] as String,
        name: j['name'] as String,
        role: FamilyRole.values.byName(j['role'] as String),
        relation: Relation.values.byName(j['relation'] as String),
        phoneNumber: j['phone_number'] as String,
        avatarUrl: j['avatar_url'] as String?,
        fcmToken: j['fcm_token'] as String?,
        phoneOem: PhoneOem.values.byName(j['phone_oem'] as String? ?? 'other'),
        lastLocation: j['last_location'] == null
            ? null
            : LastLocation.fromJson(j['last_location'] as Map<String, dynamic>),
        isSharingLocation: j['is_sharing_location'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
