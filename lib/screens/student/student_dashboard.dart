import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:keitask_management/models/task_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_task_service.dart';
import '../../services/auth_service.dart';
import '../profile/progress_detail_screen.dart';
import '../../utils/attachment_helper.dart';
import 'task_submission_screen.dart';
import 'submission_details_dialog.dart';

class StudentDashboard extends StatefulWidget {
  final User user;
  final VoidCallback? onSeeAllTasks;

  const StudentDashboard({super.key, required this.user, this.onSeeAllTasks});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  // Helper to format date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    // Date comparison logic wraps here implicitly
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

        // Student Logic: Filter tasks assigned to me
        final myTasks = allTasks
            .where((t) => t.assignees.contains(currentUserId))
            .toList();

        // 1. Assigned (Not submitted, not completed)
        int stat1Count = myTasks.where((t) {
          final hasSubmitted =
              t.submissions?.containsKey(currentUserId) ?? false;
          final isCompleted =
              t.completionStatus?.containsKey(currentUserId) ?? false;
          final isGlobalCompleted =
              t.status.toLowerCase() == 'completed' ||
              t.status.toLowerCase() == 'approved';
          return !hasSubmitted &&
              !isCompleted &&
              !isGlobalCompleted &&
              t.status.toLowerCase() != 'rejected';
        }).length;
        String stat1Label = 'Assigned';
        IconData stat1Icon = Icons.assignment;
        Color stat1Color = Colors.blue;

        // 2. Pending (Submitted but waiting approval)
        int stat2Count = myTasks.where((t) {
          final hasSubmitted =
              t.submissions?.containsKey(currentUserId) ?? false;
          final isCompleted =
              t.completionStatus?.containsKey(currentUserId) ?? false;
          final isGlobalCompleted =
              t.status.toLowerCase() == 'completed' ||
              t.status.toLowerCase() == 'approved';
          return hasSubmitted &&
              !isCompleted &&
              !isGlobalCompleted &&
              t.status.toLowerCase() != 'rejected';
        }).length;
        String stat2Label = 'Pending Approval';
        IconData stat2Icon = Icons.hourglass_empty;
        Color stat2Color = Colors.orange;

        // 3. Completed
        int stat3Count = myTasks.where((t) {
          final isCompleted =
              t.completionStatus?.containsKey(currentUserId) ?? false;
          final isGlobalCompleted =
              t.status.toLowerCase() == 'completed' ||
              t.status.toLowerCase() == 'approved';
          return isCompleted || isGlobalCompleted;
        }).length;
        String stat3Label = 'Completed';
        IconData stat3Icon = Icons.check_circle;
        Color stat3Color = Colors.green;

        // Rejected / Resubmitted
        final rejectedCount = myTasks
            .where((t) => t.status.toLowerCase() == 'rejected')
            .length;
        final resubmittedCount = myTasks
            .where(
              (t) =>
                  t.status.toLowerCase() == 'resubmitted' ||
                  t.status.toLowerCase() == 'resubmit',
            )
            .length;

        // Progress Calculation
        final totalTasks = myTasks.length;
        final completionPercentage = (totalTasks > 0)
            ? ((stat3Count / totalTasks) * 100).round()
            : 0;

        // Sort by Due Date for students usually, or completed at
        myTasks.sort(
          (a, b) => (b.completedAt ?? b.dueDate).compareTo(
            a.completedAt ?? a.dueDate,
          ),
        );
        final recentTasks = myTasks.take(3).toList();

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header: Blue Gradient ---
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1565C0), // Blue 800
                          Color(0xFF1E88E5), // Blue 600
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withAlpha(50),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
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
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[800],
                                              ),
                                            )
                                          : null,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
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
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Track your progress',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withAlpha(200),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

                  // --- Status Cards Layout ---
                  Column(
                    children: [
                      // Row 1: Assigned & Pending
                      Row(
                        children: [
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1.25,
                              child: _buildStatCard(
                                stat1Label,
                                '$stat1Count',
                                stat1Color.withAlpha(50),
                                stat1Color,
                                stat1Icon,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1.25,
                              child: _buildStatCard(
                                stat2Label,
                                '$stat2Count',
                                stat2Color.withAlpha(50),
                                stat2Color,
                                stat2Icon,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 2: Rejected & Resubmitted
                      Row(
                        children: [
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1.25,
                              child: GestureDetector(
                                onTap: () =>
                                    _showRejectedTasks(context, myTasks),
                                child: _buildStatCard(
                                  'Rejected',
                                  '$rejectedCount',
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.red.withAlpha(50)
                                      : const Color(0xFFFFEBEE),
                                  Colors.red,
                                  Icons.cancel,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1.25,
                              child: _buildStatCard(
                                'Resubmitted',
                                '$resubmittedCount',
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.purple.withAlpha(50)
                                    : const Color(0xFFF3E5F5),
                                Colors.purple,
                                Icons.refresh,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 3: Completed (Full Width)
                      // Row 3: Completed (Full Width)
                      _buildWideStatCard(
                        stat3Label,
                        '$stat3Count',
                        stat3Color.withAlpha(50),
                        stat3Color,
                        stat3Icon,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Progress Overview ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress Overview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(
                            Theme.of(context).brightness == Brightness.dark
                                ? 50
                                : 10,
                          ),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Task Completion',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
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
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 12,
                            child: LinearProgressIndicator(
                              value: totalTasks > 0
                                  ? stat3Count / totalTasks
                                  : 0,
                              backgroundColor: Colors.grey[100],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$stat3Count of $totalTasks tasks completed',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${totalTasks - stat3Count} remaining',
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

                  // --- My Recent Tasks ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Recent Tasks',
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

  void _showRejectedTasks(BuildContext context, List<Task> myTasks) {
    final rejectedTasks = myTasks
        .where((t) => t.status.toLowerCase() == 'rejected')
        .toList();
    if (rejectedTasks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No rejected tasks')));
      return;
    }

    final firestore = Provider.of<FirestoreTaskService>(context, listen: false);

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
                subtitle: Text(t.rejectionReason ?? 'No reason'),
                trailing: SizedBox(
                  width: 88,
                  child: TextButton(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await firestore.resubmitTask(t.id);
                      if (!mounted) return;
                      nav.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Task marked for resubmission.'),
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

  Widget _buildWideStatCard(
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: textColor, size: 32),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
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

  void _showTaskActionsSheet(
    BuildContext screenContext,
    Task task,
    FirestoreTaskService taskService,
    User? effectiveUser,
  ) {
    showModalBottomSheet(
      context: screenContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true, // Allow full height for content
      builder: (sheetContext) {
        final statusLower = task.status.toLowerCase();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (task.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    task.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),

              // --- Attachments Section ---
              if (task.attachments != null && task.attachments!.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Attachments',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: task.attachments!.length,
                    itemBuilder: (context, index) {
                      final url = task.attachments![index];
                      final uri = Uri.parse(url);
                      final fileName =
                          uri.queryParameters['originalName'] ??
                          url.split('/').last.split('?').first;
                      final isPdf = url.toLowerCase().contains('.pdf');
                      final isImage =
                          url.toLowerCase().contains('.jpg') ||
                          url.toLowerCase().contains('.jpeg') ||
                          url.toLowerCase().contains('.png');

                      return GestureDetector(
                        onTap: () =>
                            AttachmentHelper.openAttachment(context, url),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPdf
                                    ? Icons.picture_as_pdf
                                    : (isImage
                                          ? Icons.image
                                          : Icons.description),
                                color: isPdf
                                    ? Colors.red
                                    : (isImage ? Colors.purple : Colors.blue),
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  fileName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Divider(height: 1),

              if (statusLower == 'rejected')
                ListTile(
                  leading: const Icon(Icons.report_problem, color: Colors.red),
                  title: const Text(
                    'View Rejection Reason',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showDialog(
                      context: screenContext,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Rejection Reason'),
                        content: Text(
                          task.rejectionReason ?? 'No reason provided.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Action: Submit/Resubmit
              if (effectiveUser?.role != 'admin' &&
                  effectiveUser?.role != 'professor')
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.blue),
                  title: Text(
                    statusLower == 'rejected' ? 'Resubmit Task' : 'Submit Task',
                    style: TextStyle(
                      color: statusLower == 'rejected'
                          ? Colors.red
                          : Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      screenContext,
                      MaterialPageRoute(
                        builder: (context) => TaskSubmissionScreen(
                          task: task,
                          user: effectiveUser!,
                        ),
                      ),
                    );
                  },
                ),

              // Action: View Submission (if pending or completed)
              if (statusLower == 'pending' ||
                  statusLower == 'approved' ||
                  statusLower == 'completed' ||
                  (task.submissions?.containsKey(effectiveUser?.id) ?? false))
                ListTile(
                  leading: const Icon(Icons.visibility, color: Colors.grey),
                  title: const Text('View My Submission'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (effectiveUser != null &&
                        task.submissions != null &&
                        task.submissions!.containsKey(effectiveUser.id)) {
                      showDialog(
                        context: screenContext,
                        builder: (_) => SubmissionDetailsDialog(
                          task: task,
                          studentId: effectiveUser.id,
                          submissionUrls: task.submissions![effectiveUser.id]!,
                          viewer: effectiveUser,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(screenContext).showSnackBar(
                        const SnackBar(content: Text('No submission found')),
                      );
                    }
                  },
                ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentTaskCard(Task task) {
    final statusColor = _getStatusColor(task.status);
    final firestore = Provider.of<FirestoreTaskService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final effectiveUser = auth.appUser ?? widget.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () =>
            _showTaskActionsSheet(context, task, firestore, effectiveUser),
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
          child: Column(
            children: [
              Row(
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton(
                  onPressed: () => _showTaskActionsSheet(
                    context,
                    task,
                    firestore,
                    effectiveUser,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: Colors.blue.withAlpha(50)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'View Task & Instructions',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
