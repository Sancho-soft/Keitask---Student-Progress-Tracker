// lib/screens/auth/tasks/admin_tasks_approval_screen.dart (FIREBASE INTEGRATION)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/task_service.dart';
import '../../services/firestore_task_service.dart';
import '../../models/grade_model.dart';

class AdminTasksApprovalScreen extends StatefulWidget {
  final User user;

  const AdminTasksApprovalScreen({super.key, required this.user});

  @override
  State<AdminTasksApprovalScreen> createState() =>
      _AdminTasksApprovalScreenState();
}

class _AdminTasksApprovalScreenState extends State<AdminTasksApprovalScreen> {
  String _filterStatus = 'all'; // Track filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _showGradeDialog(
    BuildContext context,
    String taskId,
    String studentId,
    FirestoreTaskService firestoreTaskService,
  ) {
    final scoreController = TextEditingController();
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grade Submission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreController,
              decoration: const InputDecoration(
                labelText: 'Score (0-100)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Comment (Optional)',
                border: OutlineInputBorder(),
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
              final scoreText = scoreController.text.trim();
              if (scoreText.isEmpty) {
                _showFeedback(context, 'Please enter a score');
                return;
              }
              final score = double.tryParse(scoreText);
              if (score == null || score < 0 || score > 100) {
                _showFeedback(context, 'Invalid score (0-100)');
                return;
              }

              final grade = Grade(
                score: score,
                maxScore: 100,
                comment: commentController.text.trim(),
                gradedBy: widget.user.id,
                gradedAt: DateTime.now(),
              );

              await firestoreTaskService.gradeTask(taskId, studentId, grade);
              if (!context.mounted) return;
              Navigator.pop(context);
              _showFeedback(context, 'Task graded successfully');
            },
            child: const Text('Save Grade'),
          ),
        ],
      ),
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
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
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

          // Filter Chips (Matching Figma: All/Pending/Approvals)
          // Filter Chips (Matching Figma: All/Pending/Approvals)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
                    'Submissions',
                    isSelected: _filterStatus == 'pending',
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _filterStatus = 'approvals'),
                  child: _buildFilterChip(
                    'Approvals',
                    isSelected: _filterStatus == 'approvals',
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _filterStatus = 'completed'),
                  child: _buildFilterChip(
                    'Completed',
                    isSelected: _filterStatus == 'completed',
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

                // Deduplicate tasks based on ID
                final uniqueTasksMap = <String, Task>{};
                for (var task in allTasks) {
                  uniqueTasksMap[task.id] = task;
                }
                var filteredTasks = uniqueTasksMap.values.toList();

                // Search Filter
                if (_searchQuery.isNotEmpty) {
                  filteredTasks = filteredTasks
                      .where(
                        (t) => t.title.toLowerCase().contains(_searchQuery),
                      )
                      .toList();
                }

                // If Professor, only show tasks created by them
                if (widget.user.role == 'professor') {
                  filteredTasks = filteredTasks
                      .where((t) => t.creator == widget.user.id)
                      .toList();
                }
                if (_filterStatus == 'pending') {
                  filteredTasks = filteredTasks
                      .where(
                        (t) =>
                            t.status.toLowerCase() == 'pending' ||
                            t.status.toLowerCase() == 'resubmitted',
                      )
                      .toList();
                } else if (_filterStatus == 'approvals') {
                  filteredTasks = filteredTasks
                      .where(
                        (t) => t.status.toLowerCase() == 'pending_approval',
                      )
                      .toList();
                } else if (_filterStatus == 'completed') {
                  filteredTasks = filteredTasks
                      .where(
                        (t) =>
                            t.status.toLowerCase() == 'completed' ||
                            t.status.toLowerCase() == 'approved',
                      )
                      .toList();
                }

                if (filteredTasks.isEmpty) {
                  return Center(
                    child: Text(
                      _filterStatus == 'pending'
                          ? 'No pending submissions.'
                          : (_filterStatus == 'approvals'
                                ? 'No pending approvals.'
                                : 'No tasks found.'),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    final assigneeId = task.assignees.isNotEmpty
                        ? task.assignees.first
                        : '';
                    final assigneeName = assigneeId.isNotEmpty
                        ? taskService.getUserName(assigneeId)
                        : '';
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
    // Determine the status color and chips (case-insensitive)
    final statusLc = task.status.toLowerCase();
    final isPendingSubmission =
        statusLc == 'pending' || statusLc == 'resubmitted';
    final isPendingApproval = statusLc == 'pending_approval';
    final isRejected = statusLc == 'rejected';

    final Color statusColor = (isPendingSubmission || isPendingApproval)
        ? Colors.orange
        : (statusLc == 'approved' || statusLc == 'assigned'
              ? Colors.green
              : Colors.red);

    String statusText = task.status.toUpperCase();
    if (isPendingApproval) statusText = 'NEEDS APPROVAL';

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
              assigneeName.isNotEmpty
                  ? assigneeName
                  : 'Created by ${task.creator}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),

            const SizedBox(height: 12),

            // Submission Display (if any)
            if (task.submissions != null &&
                task.assignees.isNotEmpty &&
                task.submissions!.containsKey(task.assignees.first)) ...[
              const Text(
                'Submission:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              ...task.submissions![task.assignees.first]!.map((url) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Submission Link'),
                          content: SelectableText(url),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attachment,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            url.split('/').last,
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
            ],

            // Submission Notes (if any)
            if (task.submissionNotes != null &&
                task.assignees.isNotEmpty &&
                task.submissionNotes!.containsKey(task.assignees.first)) ...[
              const Text(
                'Student Notes:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  task.submissionNotes![task.assignees.first]!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Submission Date
            if (task.completionStatus != null &&
                task.assignees.isNotEmpty &&
                task.completionStatus!.containsKey(task.assignees.first)) ...[
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Submitted: ${_formatDate(task.completionStatus![task.assignees.first]!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Status and Notes Area (Matching Figma)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
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
                  const SizedBox(width: 8),

                  // Rejection Reason (if rejected)
                  if (isRejected && task.rejectionReason != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Reason: ${task.rejectionReason}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 28,
                      child: ElevatedButton(
                        onPressed: () async {
                          await firestoreTaskService.resubmitTask(task.id);
                          if (!context.mounted) return;
                          _showFeedback(
                            context,
                            'Task marked for resubmission.',
                          );
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
                  ] else if (isPendingSubmission || isPendingApproval)
                    // Approve and Reject Buttons
                    if (widget.user.role == 'admin' ||
                        (!isPendingApproval && widget.user.role == 'professor'))
                      Row(
                        children: [
                          // Approve Button
                          SizedBox(
                            height: 28,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (isPendingApproval) {
                                  await firestoreTaskService
                                      .approveProfessorTask(task.id);
                                  if (!context.mounted) return;
                                  _showFeedback(
                                    context,
                                    'Task Approved (Assigned).',
                                  );
                                } else {
                                  await firestoreTaskService.approveTask(
                                    task.id,
                                  );
                                  if (!context.mounted) return;
                                  _showFeedback(
                                    context,
                                    'Task Approved (Completed).',
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
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
                          // Grade Button (For Professors reviewing submissions)
                          if (isPendingSubmission &&
                              widget.user.role == 'professor') ...[
                            SizedBox(
                              height: 28,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (task.assignees.isNotEmpty) {
                                    _showGradeDialog(
                                      context,
                                      task.id,
                                      task.assignees.first,
                                      firestoreTaskService,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Grade',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
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
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    String timeStr =
        '${date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour)}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';

    if (isToday) {
      return 'Today at $timeStr';
    } else {
      return '${date.day}/${date.month}/${date.year} at $timeStr';
    }
  }
}
