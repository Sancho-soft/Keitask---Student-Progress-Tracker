import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../widgets/leaderboard_widgets.dart';

class ProfessorLeaderboard extends StatelessWidget {
  final User professor;

  const ProfessorLeaderboard({super.key, required this.professor});

  @override
  Widget build(BuildContext context) {
    // 1. Fetch tasks created by this professor to find their students
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('creator', isEqualTo: professor.id)
          .snapshots(),
      builder: (context, taskSnapshot) {
        if (taskSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (taskSnapshot.hasError) {
          debugPrint('Professor Leaderboard Task Error: ${taskSnapshot.error}');
          return const Center(child: Text('Error loading class data'));
        }

        final tasks = taskSnapshot.data?.docs ?? [];
        final Set<String> studentIds = {};

        debugPrint(
          'Professor Leaderboard: Found ${tasks.length} tasks for creator ${professor.id}',
        );

        for (var doc in tasks) {
          try {
            // Robust parsing using the Task model logic (handles 'assignees' vs 'assignee')
            final data = doc.data() as Map<String, dynamic>;
            // Temporarily use Task.fromJson to ensure consistency, or manual fallback
            List<String> taskAssignees = [];
            if (data['assignees'] is List) {
              taskAssignees = List<String>.from(
                (data['assignees'] as List).map((e) => e.toString()),
              );
            } else if (data['assignee'] != null) {
              taskAssignees = [data['assignee'].toString()];
            }

            studentIds.addAll(taskAssignees);
          } catch (e) {
            debugPrint('Error parsing task assignees for doc ${doc.id}: $e');
          }
        }

        debugPrint(
          'Professor Leaderboard: extracted ${studentIds.length} unique student IDs: $studentIds',
        );

        if (studentIds.isEmpty) {
          return const Center(
            child: Text('No students assigned to your tasks yet.'),
          );
        }

        // 2. Fetch all students (users) to filter by ID
        // We fetch all users to ensure we don't miss anyone due to role mismatch (e.g. 'Student' vs 'student')
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (userSnapshot.hasError) {
              return const Center(child: Text('Error loading students'));
            }

            final allStudents = userSnapshot.data?.docs ?? [];

            // Filter and Sort
            final myStudents = allStudents.where((doc) {
              return studentIds.contains(doc.id);
            }).toList();

            debugPrint('Professor Leaderboard: Filtering results.');
            for (var s in myStudents) {
              final d = s.data() as Map<String, dynamic>;
              debugPrint(
                'Student: ${d['name']} (${s.id}) - Points: ${d['points']}',
              );
            }

            myStudents.sort((a, b) {
              final pA = (a.data() as Map<String, dynamic>)['points'] ?? 0;
              final pB = (b.data() as Map<String, dynamic>)['points'] ?? 0;
              return pB.compareTo(pA); // Descending
            });

            return LeaderboardWidgets.buildLeaderboardContent(
              context,
              myStudents,
            );
          },
        );
      },
    );
  }
}
