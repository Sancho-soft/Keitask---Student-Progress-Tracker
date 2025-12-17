import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_task_service.dart';
import 'professor_leaderboard.dart';
import '../../widgets/leaderboard_widgets.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  void _showResetLeaderboardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Leaderboard'),
        content: const Text(
          'Are you sure you want to reset all student points to 0? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              // Show loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Resetting leaderboard...')),
              );

              try {
                final firestore = Provider.of<FirestoreTaskService>(
                  context,
                  listen: false,
                );
                final usersRef = firestore.firestore.collection('users');
                final students = await usersRef
                    .where('role', isEqualTo: 'student')
                    .get();

                final batch = firestore.firestore.batch();
                for (var doc in students.docs) {
                  batch.update(doc.reference, {'points': 0});
                }
                await batch.commit();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Leaderboard reset successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error resetting leaderboard: $e')),
                  );
                }
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.appUser;
    final isProfessor = user?.role == 'professor';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isProfessor ? 'My Class Leaderboard' : 'Leaderboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          if (user?.role == 'admin')
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red),
              onPressed: () => _showResetLeaderboardDialog(context),
              tooltip: 'Reset Leaderboard',
            ),
        ],
      ),
      body: isProfessor
          ? ProfessorLeaderboard(professor: user!)
          : _buildGlobalLeaderboard(context),
    );
  }

  Widget _buildGlobalLeaderboard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .orderBy('points', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data?.docs ?? [];
        return LeaderboardWidgets.buildLeaderboardContent(context, users);
      },
    );
  }
}
