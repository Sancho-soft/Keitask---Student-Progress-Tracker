// lib/screens/auth/tasks/admin_tasks_approval_screen.dart (FIREBASE INTEGRATION)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../services/task_service.dart';
import '../../../services/firestore_task_service.dart';

class AdminTasksApprovalScreen extends StatefulWidget {
  final User user;

  const AdminTasksApprovalScreen({super.key, required this.user});

  @override
  State<AdminTasksApprovalScreen> createState() =>
      _AdminTasksApprovalScreenState();
}

class _AdminTasksApprovalScreenState extends State<AdminTasksApprovalScreen> {
  String _filterStatus = 'all'; // Track filter state

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
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
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                _showFeedback(context, 'Please enter a rejection reason');
                return;
              }
              await firestoreTaskService.rejectTask(taskId, reason);
              if (!context.mounted) return;
              Navigator.pop(context);
              _showFeedback(context, 'Task rejected with reason: $reason');
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(context);
    final firestoreTaskService = Provider.of<FirestoreTaskService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tasks', // Title is 'Tasks' in the Figma screenshot
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and Filter Bar (Matching Figma)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Tasks...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // Filter Chips (Matching Figma: All/Pending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _filterStatus = 'all'),
                  child: _buildFilterChip(
                    'All',
                    isSelected: _filterStatus == 'all',
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _filterStatus = 'pending'),
                  child: _buildFilterChip(
                    'Pending',
                    isSelected: _filterStatus == 'pending',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Task List (Real-time from Firebase)
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: firestoreTaskService.tasksStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allTasks = snapshot.data ?? [];

                // Apply filter
                final filteredTasks = _filterStatus == 'pending'
                    ? allTasks.where((t) => t.status == 'pending').toList()
                    : allTasks;

                if (filteredTasks.isEmpty) {
                  return Center(
                    child: Text(
                      _filterStatus == 'pending'
                          ? 'No pending tasks.'
                          : 'No tasks created yet.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    final assigneeName = taskService.getUserName(task.assignee);
                    return _buildTaskReviewCard(
                      context,
                      task,
                      firestoreTaskService,
                      assigneeName,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool isSelected}) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.blue.withAlpha((0.1 * 255).round()),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      onSelected: (_) {}, // Handled by GestureDetector
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildTaskReviewCard(
    BuildContext context,
    Task task,
    FirestoreTaskService firestoreTaskService,
    String assigneeName,
  ) {
    // Determine the status color and chips
    final isPending = task.status == 'pending';
    final isRejected = task.status == 'rejected';
    final Color statusColor = isPending
        ? Colors.orange
        : (task.status == 'approved' ? Colors.green : Colors.red);
    final String statusText = task.status.toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              assigneeName,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),

            const SizedBox(height: 12),

            // Status and Notes Area (Matching Figma)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Rejection Reason (if rejected)
                if (isRejected && task.rejectionReason != null) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        'Reason: ${task.rejectionReason}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () async {
                        await firestoreTaskService.resubmitTask(task.id);
                        if (!context.mounted) return;
                        _showFeedback(context, 'Task marked for resubmission.');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Resubmit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ] else if (isPending)
                  // Approve and Reject Buttons (Only visible if pending)
                  Row(
                    children: [
                      // Approve Button
                      SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () async {
                            await firestoreTaskService.approveTask(task.id);
                            if (!context.mounted) return;
                            _showFeedback(context, 'Task Approved.');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Approve',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Reject Button
                      SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () {
                            _showRejectDialog(
                              context,
                              task.id,
                              firestoreTaskService,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Reject',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
