// lib/models/user_model.dart

class User {
  final String id;
  final String email;
  final String name;
  final String role; // 'user', 'student', 'professor', 'admin'
  final String? profileImage;
  final int points;
  final bool isApproved;
  final DateTime? createdAt;
  final DateTime? lastActive;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.profileImage,
    this.isApproved = true,
    this.enrolledCourseIds,
    this.teachingCourseIds,
    this.phoneNumber,
    this.isBanned = false,
    this.notificationsEnabled,
    this.points = 0,
    this.address,
    this.createdAt,
    this.lastActive,
  });

  final List<String>? enrolledCourseIds;
  final List<String>? teachingCourseIds;
  final String? phoneNumber;
  final String? address;
  final bool isBanned;
  final bool? notificationsEnabled;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: json['role'],
      profileImage: json['profileImage'],
      isApproved: json['isApproved'] ?? true,
      enrolledCourseIds: json['enrolledCourseIds'] != null
          ? List<String>.from(json['enrolledCourseIds'])
          : null,
      teachingCourseIds: json['teachingCourseIds'] != null
          ? List<String>.from(json['teachingCourseIds'])
          : null,
      phoneNumber: json['phoneNumber'],
      isBanned: json['isBanned'] ?? false,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      points: json['points'] ?? 0,
      address: json['address'],
      createdAt: _parseDateTime(json['createdAt']),
      lastActive: _parseDateTime(json['lastActive']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    // Handle Firestore Timestamp (which has toDate())
    try {
      return (value as dynamic).toDate();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'profileImage': profileImage,
      'isApproved': isApproved,
      'enrolledCourseIds': enrolledCourseIds,
      'teachingCourseIds': teachingCourseIds,
      'phoneNumber': phoneNumber,
      'address': address,
      'isBanned': isBanned,
      'notificationsEnabled': notificationsEnabled,
      'points': points,
      'createdAt': createdAt,
      'lastActive': lastActive,
    };
  }
}
