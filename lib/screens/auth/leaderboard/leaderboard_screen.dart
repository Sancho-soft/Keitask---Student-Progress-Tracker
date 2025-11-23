import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/task_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_task_service.dart';
import '../../../models/user_model.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(context);
    final authService = Provider.of<AuthService>(context);
    final firestoreTaskService = Provider.of<FirestoreTaskService>(
      context,
      listen: false,
    );

    final dashboardAncestor = context
        .findAncestorWidgetOfExactType<DashboardScreen>();
    final isAdmin = dashboardAncestor?.user.role == 'admin';

    return FutureBuilder<List<User>>(
      future: authService.getAllUsers(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final users = userSnap.data ?? <User>[];
        taskService.setUserNames({for (var u in users) u.id: u.name});

        return StreamBuilder<List<Task>>(
          stream: firestoreTaskService.tasksStream(),
          builder: (context, taskSnap) {
            if (taskSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final tasks = taskSnap.data ?? [];

            // Build counts and last completion maps
            final Map<String, int> counts = {for (var u in users) u.id: 0};
            final Map<String, DateTime?> lastAt = {
              for (var u in users) u.id: null,
            };

            for (final t in tasks) {
              final assignee = t.assignee;
              if (!counts.containsKey(assignee)) continue;
              if (t.status == 'completed' || t.status == 'approved') {
                counts[assignee] = (counts[assignee] ?? 0) + 1;
                final cand = t.completedAt ?? t.dueDate;
                final prev = lastAt[assignee];
                if (prev == null || cand.isAfter(prev)) {
                  lastAt[assignee] = cand;
                }
              }
            }

            final entries = users.where((u) => u.role != 'admin').map((u) {
              return {
                'user': u,
                'completed': counts[u.id] ?? 0,
                'last': lastAt[u.id],
              };
            }).toList();

            entries.sort((a, b) {
              final ac = a['completed'] as int;
              final bc = b['completed'] as int;
              if (ac != bc) return bc.compareTo(ac);
              final ad = a['last'] as DateTime?;
              final bd = b['last'] as DateTime?;
              if (ad != null && bd != null) return bd.compareTo(ad);
              if (ad != null) return -1;
              if (bd != null) return 1;
              return (a['user'] as User).name.compareTo(
                (b['user'] as User).name,
              );
            });

            return Scaffold(
              appBar: AppBar(title: const Text('Leaderboard')),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (entries.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          entries.length >= 3 ? 3 : entries.length,
                          (i) {
                            final e = entries[i];
                            final user = e['user'] as User;
                            final completed = e['completed'] as int;
                            return GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(
                                    user: user,
                                    onBackToHome: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundImage:
                                        (user.profileImage ?? '').isNotEmpty
                                        ? NetworkImage(user.profileImage!)
                                        : null,
                                    child: (user.profileImage ?? '').isEmpty
                                        ? Text(
                                            user.name.isNotEmpty
                                                ? user.name[0].toUpperCase()
                                                : 'U',
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$completed tasks',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Expanded(
                      child: ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final e = entries[idx];
                          final user = e['user'] as User;
                          final completed = e['completed'] as int;
                          return ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(
                                  user: user,
                                  onBackToHome: () =>
                                      Navigator.of(context).pop(),
                                ),
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundImage:
                                  (user.profileImage ?? '').isNotEmpty
                                  ? NetworkImage(user.profileImage!)
                                  : null,
                              child: (user.profileImage ?? '').isEmpty
                                  ? Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : 'U',
                                    )
                                  : null,
                            ),
                            title: Text(user.name),
                            subtitle: Text('$completed completed'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$completed',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    if (isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: TextButton.icon(
                          onPressed: () => Provider.of<TaskService>(
                            context,
                            listen: false,
                          ).resetLeaderboard(),
                          icon: const Icon(
                            Icons.history_toggle_off,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'RESET LEADERBOARD',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
