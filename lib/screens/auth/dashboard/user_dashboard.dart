// lib/screens/auth/dashboard/user_dashboard.dart (FINAL FIX - OVERFLOW RESOLVED)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_task_service.dart';
import '../../../services/auth_service.dart';
import '../profile/progress_detail_screen.dart';

class UserDashboard extends StatefulWidget {
  final User user;

  const UserDashboard({super.key, required this.user});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final firestore = Provider.of<FirestoreTaskService>(context);

    // Use Firestore stream so counts reflect real persisted tasks
    return StreamBuilder<List<Task>>(
      stream: firestore.tasksStream(),
      builder: (context, snap) {
        final allTasks = snap.data ?? <Task>[];
        final currentUserId = auth.appUser?.id ?? widget.user.id;

        // Filter tasks assigned (supporting multi-assignees) or created by current user
        final userTasks = allTasks
            .where(
              (task) =>
                  task.assignees.contains(currentUserId) ||
                  task.creator == currentUserId,
            )
            .toList();

        final approvedCount = userTasks
            .where((t) => t.status.toLowerCase() == 'approved')
            .length;
        final pendingCount = userTasks
            .where(
              (t) =>
                  t.status.toLowerCase() == 'pending' ||
                  t.status.toLowerCase() == 'assigned',
            )
            .length;
        final rejectedCount = userTasks
            .where((t) => t.status.toLowerCase() == 'rejected')
            .length;
        final resubmittedCount = userTasks
            .where(
              (t) =>
                  t.status.toLowerCase() == 'resubmitted' ||
                  t.status.toLowerCase() == 'resubmit',
            )
            .length;
        // Completed should reflect only fully completed tasks (not just approved)
        final completedCount = userTasks
            .where((t) => t.status.toLowerCase() == 'completed')
            .length;
        final totalTasks = userTasks.length;
        final completionPercentage = totalTasks > 0
            ? ((completedCount / totalTasks) * 100).round()
            : 0;
        userTasks.sort(
          (a, b) => (b.completedAt ?? b.dueDate).compareTo(
            a.completedAt ?? a.dueDate,
          ),
        );

        final recentTasks = userTasks.take(3).toList();

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: "Hi, [username]!" and Notification Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Prefer the latest user from AuthService if available
                          Builder(
                            builder: (ctx) {
                              final displayUser = auth.appUser ?? widget.user;
                              return CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.blue.withAlpha(
                                  (0.1 * 255).round(),
                                ),
                                backgroundImage:
                                    (displayUser.profileImage != null &&
                                        displayUser.profileImage!.isNotEmpty)
                                    ? NetworkImage(displayUser.profileImage!)
                                          as ImageProvider
                                    : null,
                                child:
                                    (displayUser.profileImage == null ||
                                        displayUser.profileImage!.isEmpty)
                                    ? Text(
                                        displayUser.name.isNotEmpty
                                            ? displayUser.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${(auth.appUser?.name ?? widget.user.name).toLowerCase()}!',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Track your progress below.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Notification Icon (Matching Figma)
                      IconButton(
                        icon: const Icon(Icons.notifications_none, size: 24),
                        color: Colors.grey[600],
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No new notifications (Feature not yet implemented)',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Status Cards Grid (2x2) - OVERFLOW FIX HERE: Increased Aspect Ratio
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio:
                        1.5, // Adjusted from 1.6 to 1.5 to provide more vertical space
                    children: [
                      _buildStatCard(
                        'Approved',
                        '$approvedCount',
                        const Color(0xFFE8F5E9),
                        Colors.green,
                        Icons.check_circle,
                      ),
                      _buildStatCard(
                        'Pending',
                        '$pendingCount',
                        const Color(0xFFFFF3E0),
                        Colors.orange,
                        Icons.schedule,
                      ),
                      GestureDetector(
                        onTap: () {
                          // Show rejection reasons for user's rejected tasks
                          final rejectedTasks = userTasks
                              .where(
                                (t) => t.status.toLowerCase() == 'rejected',
                              )
                              .toList();
                          if (rejectedTasks.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No rejected tasks'),
                              ),
                            );
                            return;
                          }
                          final firestore = Provider.of<FirestoreTaskService>(
                            context,
                            listen: false,
                          );
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Rejected Tasks'),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: rejectedTasks.map((t) {
                                    return ListTile(
                                      title: Text(t.title),
                                      subtitle: Text(
                                        t.rejectionReason ?? 'No reason',
                                      ),
                                      trailing: SizedBox(
                                        width: 88,
                                        child: TextButton(
                                          onPressed: () async {
                                            // Capture navigation/messenger before async gap
                                            final nav = Navigator.of(context);
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            await firestore.resubmitTask(t.id);
                                            if (!mounted) return;
                                            nav.pop();
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Task marked for resubmission.',
                                                ),
                                              ),
                                            );
                                            setState(() {});
                                          },
                                          child: const Text('Resubmit'),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: _buildStatCard(
                          'Rejected',
                          '$rejectedCount',
                          const Color(0xFFFFEBEE),
                          Colors.red,
                          Icons.cancel,
                        ),
                      ),
                      _buildStatCard(
                        'Resubmitted',
                        '$resubmittedCount',
                        const Color(0xFFF3E5F5),
                        Colors.purple,
                        Icons.refresh,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Progress Overview (Matching Figma)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progress Overview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      // Blue Arrow Icon (tap to open progress detail)
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ProgressDetailScreen(),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.arrow_forward,
                          size: 24,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha((0.1 * 255).round()),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Task Completion',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '$completionPercentage%',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Trend Icon (Matching Figma)
                                Icon(
                                  completionPercentage >= 50
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 16,
                                  color: completionPercentage >= 50
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalTasks > 0
                                ? completedCount / totalTasks
                                : 0,
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$completedCount of $totalTasks tasks completed',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${totalTasks - completedCount} remaining',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // My Recent Tasks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Recent Tasks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/tasks',
                            arguments: widget.user,
                          ).then((_) => _refresh());
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
        ); // SafeArea
      }, // StreamBuilder.builder
    ); // StreamBuilder
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
            'No tasks yet',
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
          // Navigate to task details/edit screen
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha((0.1 * 255).round()),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(task.dueDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusBackgroundColor(task.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  task.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper functions for Stat Cards and colors (omitted for brevity, assume they exist)

  Widget _buildStatCard(
    String title,
    String count,
    Color backgroundColor,
    Color color,
    IconData icon,
  ) {
    // This widget is optimized for the 1.5 aspect ratio.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: backgroundColor,
        border: Border.all(
          color: color.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Existing color and date formatting helpers...
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'approved':
        return const Color(0xFFE8F5E9);
      case 'pending':
        return const Color(0xFFFFF3E0);
      case 'rejected':
        return const Color(0xFFFFEBEE);
      case 'resubmitted':
        return const Color(0xFFF3E5F5);
      default:
        return Colors.grey.withAlpha((0.1 * 255).round());
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'resubmitted':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
