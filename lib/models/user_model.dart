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
  // Support multiple assignees (list of user IDs) for multi-assign
  final List<String> assignees;
  // Optional human-readable names for assignees (if included from server)
  final List<String>? assigneeNames;
  final DateTime dueDate;
  final String? creator;
  final String? rejectionReason; // Reason for rejection
  final DateTime? completedAt; // optional completion timestamp
  // Per-task bookmarks tracked as list of userIds who bookmarked
  final List<String>? bookmarkedBy;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.assignees,
    this.assigneeNames,
    required this.dueDate,
    this.creator,
    this.rejectionReason,
    this.completedAt,
    this.bookmarkedBy,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    // Parse assignees as list of strings if present, otherwise fall back to single 'assignee' field
    List<String> assignees = [];
    if (json['assignees'] is List) {
      assignees = List<String>.from(json['assignees'].map((e) => e.toString()));
    } else if (json['assignee'] != null) {
      assignees = [json['assignee'].toString()];
    }

    List<String>? assigneeNames;
    if (json['assigneeNames'] is List) {
      assigneeNames = List<String>.from(
        json['assigneeNames'].map((e) => e.toString()),
      );
    } else if (json['assigneeName'] != null) {
      assigneeNames = [json['assigneeName'].toString()];
    }

    List<String>? bookmarked;
    if (json['bookmarkedBy'] is List) {
      bookmarked = List<String>.from(
        json['bookmarkedBy'].map((e) => e.toString()),
      );
    }

    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      assignees: assignees,
      assigneeNames: assigneeNames,
      dueDate: DateTime.parse(json['dueDate']),
      creator: json['creator'],
      rejectionReason: json['rejectionReason'],
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      bookmarkedBy: bookmarked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'assignees': assignees,
      'assigneeNames': assigneeNames,
      'dueDate': dueDate.toIso8601String(),
      'creator': creator,
      'rejectionReason': rejectionReason,
      'completedAt': completedAt?.toIso8601String(),
      'bookmarkedBy': bookmarkedBy,
    };
  }
}
