class StolModel {
  final String id;
  final String name;
  final String status;
  final int guestCount;
  final int capacity;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String number;
  final int v;
  final String displayName;

  StolModel({
    required this.id,
    required this.name,
    required this.status,
    required this.guestCount,
    required this.capacity,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.number,
    required this.v,
    required this.displayName,
  });

  factory StolModel.fromJson(Map<String, dynamic> json) {
    return StolModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? '',
      guestCount: json['guest_count'] ?? 0,
      capacity: json['capacity'] ?? 0,
      isActive: json['is_active'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      number: json['number'] ?? '',
      v: json['__v'] ?? 0,
      displayName: json['display_name'] ?? '',
    );
  }
}
