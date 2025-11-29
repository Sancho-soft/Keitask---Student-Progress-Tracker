class Course {
  final String id;
  final String name;
  final String code;
  final String description;
  final String teacherId; // Professor ID
  final List<String> studentIds; // Enrolled students
  final String? schedule; // e.g., "Mon/Wed 10:00 AM"

  Course({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.teacherId,
    required this.studentIds,
    this.schedule,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      description: json['description'],
      teacherId: json['teacherId'],
      studentIds: List<String>.from(json['studentIds'] ?? []),
      schedule: json['schedule'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'teacherId': teacherId,
      'studentIds': studentIds,
      'schedule': schedule,
    };
  }
}
