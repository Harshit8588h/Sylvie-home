class Family {
  final String id;
  final String name;
  final String adminId;
  final DateTime createdAt;

  const Family({
    required this.id,
    required this.name,
    required this.adminId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'admin_id': adminId,
        'created_at': createdAt.toIso8601String(),
      };

  factory Family.fromJson(Map<String, dynamic> j) => Family(
        id: j['id'] as String,
        name: j['name'] as String,
        adminId: j['admin_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
