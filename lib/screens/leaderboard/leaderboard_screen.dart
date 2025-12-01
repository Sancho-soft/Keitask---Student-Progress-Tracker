import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/task_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_task_service.dart';
import '../../models/user_model.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  final bool showBackButton;
  const LeaderboardScreen({super.key, this.showBackButton = true});

  void _navigateToProfile(BuildContext context, User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          user: user,
          onBackToHome: () => Navigator.pop(context),
        ),
      ),
    );
  }

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
              if (t.status.toLowerCase() != 'completed') continue;
              final cand = t.completedAt ?? t.dueDate;
              for (final assignee in t.assignees) {
                if (!counts.containsKey(assignee)) continue;
                counts[assignee] = (counts[assignee] ?? 0) + 1;
                final prev = lastAt[assignee];
                if (prev == null || cand.isAfter(prev)) {
                  lastAt[assignee] = cand;
                }
              }
            }

            final entries = users
                .where((u) => u.role != 'admin' && u.role != 'professor')
                .map((u) {
                  return {
                    'user': u,
                    'completed': counts[u.id] ?? 0,
                    'last': lastAt[u.id],
                  };
                })
                .toList();

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
              backgroundColor: Colors.grey[50],
              appBar: AppBar(
                title: const Text(
                  'Leaderboard',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                leading: showBackButton
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null,
                titleTextStyle: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              body: Column(
                children: [
                  if (entries.isNotEmpty) ...[
                    // Top 3 Display with Gradient Background
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha(20),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (entries.length >= 2)
                            Expanded(
                              child: _buildTopUser(context, entries[1], 2),
                            ),
                          if (entries.isNotEmpty)
                            Expanded(
                              child: _buildTopUser(context, entries[0], 1),
                            ),
                          if (entries.length >= 3)
                            Expanded(
                              child: _buildTopUser(context, entries[2], 3),
                            ),
                        ],
                      ),
                    ),
                  ],

                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: entries.length > 3 ? entries.length - 3 : 0,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final realIdx = idx + 3;
                        final e = entries[realIdx];
                        final user = e['user'] as User;
                        final completed = e['completed'] as int;
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withAlpha(10),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            onTap: () => _navigateToProfile(context, user),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    '#${realIdx + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.blue[50],
                                  backgroundImage:
                                      (user.profileImage ?? '').isNotEmpty
                                      ? NetworkImage(user.profileImage!)
                                      : null,
                                  child: (user.profileImage ?? '').isEmpty
                                      ? Text(
                                          user.name.isNotEmpty
                                              ? user.name[0].toUpperCase()
                                              : 'U',
                                          style: TextStyle(
                                            color: Colors.blue[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                            title: Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '$completed tasks completed',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${user.points} pts',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  if (isAdmin)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Provider.of<TaskService>(
                            context,
                            listen: false,
                          ).resetLeaderboard(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('RESET LEADERBOARD'),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopUser(
    BuildContext context,
    Map<String, dynamic> entry,
    int rank,
  ) {
    final user = entry['user'] as User;
    final completed = entry['completed'] as int;
    final isFirst = rank == 1;
    final double avatarSize = isFirst ? 50 : 35;
    final Color ringColor = rank == 1
        ? const Color(0xFFFFD700) // Gold
        : rank == 2
        ? const Color(0xFFC0C0C0) // Silver
        : const Color(0xFFCD7F32); // Bronze

    return GestureDetector(
      onTap: () => _navigateToProfile(context, user),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isFirst)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Icon(
                Icons.emoji_events,
                color: Color(0xFFFFD700),
                size: 40,
              ),
            )
          else
            const SizedBox(height: 48), // Spacer to align with 1st place

          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: avatarSize * 2 + 8,
                height: avatarSize * 2 + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withAlpha(50),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: avatarSize,
                backgroundColor: Colors.grey[200],
                backgroundImage: (user.profileImage ?? '').isNotEmpty
                    ? NetworkImage(user.profileImage!)
                    : null,
                child: (user.profileImage ?? '').isEmpty
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: isFirst ? 24 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ringColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isFirst ? 16 : 14,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$completed tasks',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${user.points} pts',
            style: TextStyle(
              color: ringColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
