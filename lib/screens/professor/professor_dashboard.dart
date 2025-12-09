// keitask_management/lib/screens/professor/professor_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/firestore_task_service.dart';
import '../../services/auth_service.dart';
// import '../profile/progress_detail_screen.dart'; // Professors don't track progress

class ProfessorDashboard extends StatefulWidget {
  final User user;
  final VoidCallback? onSeeAllTasks;

  const ProfessorDashboard({super.key, required this.user, this.onSeeAllTasks});

  @override
  State<ProfessorDashboard> createState() => _ProfessorDashboardState();
}

class _ProfessorDashboardState extends State<ProfessorDashboard> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  // Helper to format date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    // final difference = date.difference(now);
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day + 1) {
      return 'Tomorrow';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  // Helper for status colors
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
      case 'resubmit':
        return Colors.red;
      case 'assigned':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showNotificationsSheet(
    BuildContext context,
    List<QueryDocumentSnapshot> notifications,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        if (notifications.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No notifications')),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final data = notifications[index].data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Notification';
            final body = data['body'] ?? '';
            final notifId = notifications[index].id;
            final isRead = data['read'] ?? false;

            return ListTile(
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Text(body),
              onTap: () async {
                if (!isRead) {
                  // Mark as read
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(notifId)
                      .update({'read': true});
                }
                if (context.mounted) Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final firestore = Provider.of<FirestoreTaskService>(context);

    return StreamBuilder<List<Task>>(
      stream: firestore.tasksStream(),
      builder: (context, snap) {
        final allTasks = snap.data ?? <Task>[];
        final currentUserId = auth.appUser?.id ?? widget.user.id;

        // Professor Specific Logic
        final myCreatedTasks = allTasks
            .where((t) => t.creator == currentUserId)
            .toList();

        // 1. Active Tasks (Created but not finished)
        int stat1Count = myCreatedTasks.where((t) {
          final s = t.status.toLowerCase();
          return s != 'completed' && s != 'approved' && s != 'rejected';
        }).length;
        String stat1Label = 'Active Tasks';
        IconData stat1Icon = Icons.article;
        Color stat1Color = Colors.blue;

        // 2. Needs Grading
        int pendingGrades = 0;
        for (var t in myCreatedTasks) {
          if (t.submissions != null) {
            final subs = t.submissions!.keys;
            for (var studentId in subs) {
              if (t.grades == null || !t.grades!.containsKey(studentId)) {
                pendingGrades++;
              }
            }
          }
        }
        int stat2Count = pendingGrades;
        String stat2Label = 'Needs Grading';
        IconData stat2Icon = Icons.rate_review;
        Color stat2Color = Colors.orange;

        // 3. Completed (Approved/Completed tasks)
        int stat3Count = myCreatedTasks.where((t) {
          final s = t.status.toLowerCase();
          return s == 'completed' || s == 'approved';
        }).length;
        String stat3Label = 'Completed';
        IconData stat3Icon = Icons.check_circle;
        Color stat3Color = Colors.green;

        // Sorting for Recent Submissions (showing recently active tasks)
        myCreatedTasks.sort((a, b) => (b.id).compareTo(a.id));
        final recentTasks = myCreatedTasks.take(3).toList();

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header: Teal Gradient ---
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF00695C), // Teal 800
                          Color(0xFF4DB6AC), // Teal 300
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withAlpha(50),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Builder(
                                builder: (ctx) {
                                  final displayUser =
                                      auth.appUser ?? widget.user;
                                  return CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.white,
                                    backgroundImage:
                                        (displayUser.profileImage != null &&
                                            displayUser
                                                .profileImage!
                                                .isNotEmpty)
                                        ? NetworkImage(
                                            displayUser.profileImage!,
                                          )
                                        : null,
                                    child:
                                        (displayUser.profileImage == null ||
                                            displayUser.profileImage!.isEmpty)
                                        ? Text(
                                            displayUser.name.isNotEmpty
                                                ? displayUser.name[0]
                                                      .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal,
                                            ),
                                          )
                                        : null,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hi, ${(auth.appUser?.name ?? widget.user.name)}!',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Professor Dashboard',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(200),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Notification Icon
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('notifications')
                              .where('recipientId', isEqualTo: widget.user.id)
                              .orderBy('createdAt', descending: true)
                              .limit(50)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Icon(
                                Icons.notifications_off,
                                color: Colors.white54,
                              );
                            }

                            final notifications = snapshot.data?.docs ?? [];
                            final unreadCount = notifications
                                .where(
                                  (doc) =>
                                      !(doc.data()
                                          as Map<String, dynamic>)['read'],
                                )
                                .length;

                            return Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(30),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.notifications_none_rounded,
                                      size: 26,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      _showNotificationsSheet(
                                        context,
                                        notifications,
                                      );
                                    },
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 12,
                                    top: 12,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 8,
                                        minHeight: 8,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // --- Status Cards Grid ---
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _buildStatCard(
                        stat1Label,
                        '$stat1Count',
                        stat1Color.withAlpha(50),
                        stat1Color,
                        stat1Icon,
                      ),
                      _buildStatCard(
                        stat2Label,
                        '$stat2Count',
                        stat2Color.withAlpha(50),
                        stat2Color,
                        stat2Icon,
                      ),
                      _buildStatCard(
                        stat3Label,
                        '$stat3Count',
                        stat3Color.withAlpha(50),
                        stat3Color,
                        stat3Icon,
                      ),
                      // No Rejection/Resubmit cards for Professor
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Recent Submissions ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Created Tasks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (widget.onSeeAllTasks != null) {
                            widget.onSeeAllTasks!();
                          } else {
                            Navigator.pushNamed(
                              context,
                              '/tasks',
                              arguments: widget.user,
                            ).then((_) => _refresh());
                          }
                        },
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  recentTasks.isEmpty
                      ? Center(child: _buildEmptyTasksPlaceholder())
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recentTasks.length,
                          itemBuilder: (context, index) {
                            final task = recentTasks[index];
                            return _buildRecentTaskCard(task);
                          },
                        ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    Color bgColor,
    Color textColor,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              Theme.of(context).brightness == Brightness.dark ? 50 : 10,
            ),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: textColor, size: 24),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTasksPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No tasks created yet',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first task to get started',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTaskCard(Task task) {
    final statusColor = _getStatusColor(task.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Provide navigation if needed, or rely on 'onSeeAllTasks'
          // Navigator.pushNamed(context, '/task-details', arguments: task);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(
                  Theme.of(context).brightness == Brightness.dark ? 50 : 10,
                ),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(task.dueDate),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
