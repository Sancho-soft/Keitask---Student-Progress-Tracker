class Grade {
  final double score;
  final double maxScore;
  final String? comment;
  final String gradedBy; // User ID of the professor
  final DateTime gradedAt;

  Grade({
    required this.score,
    required this.maxScore,
    this.comment,
    required this.gradedBy,
    required this.gradedAt,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      score: (json['score'] as num).toDouble(),
      maxScore: (json['maxScore'] as num).toDouble(),
      comment: json['comment'],
      gradedBy: json['gradedBy'],
      gradedAt: DateTime.parse(json['gradedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'maxScore': maxScore,
      'comment': comment,
      'gradedBy': gradedBy,
      'gradedAt': gradedAt.toIso8601String(),
    };
  }
}
