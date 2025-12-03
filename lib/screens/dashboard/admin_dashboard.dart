// lib/screens/auth/dashboard/admin_dashboard.dart (UPDATED WITH REJECTION REASON)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/task_service.dart';
import '../../services/firestore_task_service.dart';
import '../../services/auth_service.dart';
import '../admin/task_statistics_screen.dart';

class AdminDashboard extends StatefulWidget {
  final User user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  void _refresh() {
    // Provider handles updates automatically.
  }

  void _showRejectDialog(
    BuildContext context,
    String taskId,
    FirestoreTaskService firestoreTaskService,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason'),
                  ),
                );
                return;
              }
              firestoreTaskService.rejectTask(taskId, reason);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Task rejected with reason: $reason')),
              );
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use Provider to get the service instance
    final taskService = Provider.of<TaskService>(context);
    final firestoreTaskService = Provider.of<FirestoreTaskService>(context);
    final auth = Provider.of<AuthService>(context, listen: false);

    // Stream tasks and derive counts from Firestore to ensure accuracy
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<Task>>(
        stream: firestoreTaskService.tasksStream(),
        builder: (context, snapshot) {
          final allTasks = snapshot.data ?? [];

          final approvedCount = allTasks
              .where((t) => t.status.toLowerCase() == 'approved')
              .length;
          final pendingCount = allTasks
              .where((t) => t.status.toLowerCase() == 'pending')
              .length;
          final rejectedCount = allTasks
              .where((t) => t.status.toLowerCase() == 'rejected')
              .length;
          final resubmittedCount = allTasks
              .where(
                (t) =>
                    t.status.toLowerCase() == 'resubmitted' ||
                    t.status.toLowerCase() == 'resubmit',
              )
              .length;

          final pendingTasksReviews = allTasks
              .where(
                (task) =>
                    task.status.toLowerCase() == 'pending' ||
                    task.status.toLowerCase() == 'resubmitted',
              )
              .toList();

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Blue Header Section
                  Container(
                    width: double.infinity,
                    color: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${auth.appUser?.name ?? widget.user.name}!',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Track your progress below.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          backgroundImage:
                              (auth.appUser?.profileImage != null &&
                                  auth.appUser!.profileImage!.isNotEmpty)
                              ? NetworkImage(auth.appUser!.profileImage!)
                                    as ImageProvider
                              : null,
                          child:
                              (auth.appUser == null ||
                                  auth.appUser!.profileImage == null ||
                                  auth.appUser!.profileImage!.isEmpty)
                              ? Text(
                                  widget.user.name.isNotEmpty
                                      ? widget.user.name[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  // Content Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Cards Grid (2x2) - OVERFLOW FIX APPLIED HERE
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio:
                              1.5, // FIX: This resolves the overflow
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
                            _buildStatCard(
                              'Rejected',
                              '$rejectedCount',
                              const Color(0xFFFFEBEE),
                              Colors.red,
                              Icons.cancel,
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

                        // Pending Tasks Reviews Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pending Tasks Reviews',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // Navigates to the dedicated approval screen (Tasks tab)
                                // Note: AdminTasksApprovalScreen uses this same data source.
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const TaskStatisticsScreen(),
                                  ),
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
                        pendingTasksReviews.isEmpty
                            ? Center(
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.task_alt,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No pending reviews',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'All tasks have been reviewed',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: pendingTasksReviews.length,
                                itemBuilder: (context, index) {
                                  final task = pendingTasksReviews[index];
                                  final assigneeId = task.assignees.isNotEmpty
                                      ? task.assignees.first
                                      : '';
                                  final assigneeName = assigneeId.isNotEmpty
                                      ? taskService.getUserName(assigneeId)
                                      : '';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withAlpha(
                                              (0.1 * 255).round(),
                                            ),
                                            spreadRadius: 1,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  task.title,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'by $assigneeName', // Now displays name
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.visibility,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () {
                                              // View task details
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text(task.title),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Description: ${task.description}',
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Assignee: $assigneeName',
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Due Date: ${_formatDate(task.dueDate)}',
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        _showRejectDialog(
                                                          context,
                                                          task.id,
                                                          firestoreTaskService,
                                                        );
                                                      },
                                                      child: const Text(
                                                        'Reject',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        // Use the FirestoreTaskService method
                                                        firestoreTaskService
                                                            .approveTask(
                                                              task.id,
                                                            );
                                                        Navigator.pop(context);
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Task approved',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      child: const Text(
                                                        'Approve',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    Color backgroundColor,
    Color color,
    IconData icon,
  ) {
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
}
