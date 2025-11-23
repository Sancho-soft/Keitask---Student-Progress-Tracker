// lib/models/user_model.dart
class User {
  final String id;
  final String email;
  final String name;
  final String role; // 'user' or 'admin'
  final String? profileImage;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.profileImage,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: json['role'],
      profileImage: json['profileImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'profileImage': profileImage,
    };
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final String
  status; // 'pending', 'approved', 'completed', 'rejected', 'resubmitted'
  final String assignee;
  final DateTime dueDate;
  final String? creator;
  final String? rejectionReason; // Reason for rejection
  final DateTime? completedAt; // optional completion timestamp

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.assignee,
    required this.dueDate,
    this.creator,
    this.rejectionReason,
    this.completedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      assignee: json['assignee'],
      dueDate: DateTime.parse(json['dueDate']),
      creator: json['creator'],
      rejectionReason: json['rejectionReason'],
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'assignee': assignee,
      'dueDate': dueDate.toIso8601String(),
      'creator': creator,
      'rejectionReason': rejectionReason,
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}
