import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reporterEmail;
  final String title;
  final String description;
  final String type; // 'bug', 'login_error', 'suggestion', 'other'
  final String status; // 'open', 'resolved'
  final DateTime createdAt;

  Report({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reporterEmail,
    required this.title,
    required this.description,
    required this.type,
    this.status = 'open',
    required this.createdAt,
  });

  factory Report.fromMap(Map<String, dynamic> map, String id) {
    return Report(
      id: id,
      reporterId: map['reporterId'] ?? '',
      reporterName: map['reporterName'] ?? '',
      reporterEmail: map['reporterEmail'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'other',
      status: map['status'] ?? 'open',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reporterEmail': reporterEmail,
      'title': title,
      'description': description,
      'type': type,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
