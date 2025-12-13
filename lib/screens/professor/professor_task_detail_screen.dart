import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/user_model.dart';
import '../../models/grade_model.dart';
import '../../services/firestore_task_service.dart';
import '../../services/auth_service.dart';

class ProfessorTaskDetailScreen extends StatefulWidget {
  final Task task;
  final User user;

  const ProfessorTaskDetailScreen({
    super.key,
    required this.task,
    required this.user,
  });

  @override
  State<ProfessorTaskDetailScreen> createState() =>
      _ProfessorTaskDetailScreenState();
}

class _ProfessorTaskDetailScreenState extends State<ProfessorTaskDetailScreen> {
  late Task _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to task updates to refresh the view (e.g., after grading)
    final firestoreService = Provider.of<FirestoreTaskService>(context);

    return StreamBuilder<List<Task>>(
      stream: firestoreService.tasksStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final updated = snapshot.data!
              .where((t) => t.id == widget.task.id)
              .firstOrNull;
          if (updated != null) {
            _currentTask = updated;
          }
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Task Details'), elevation: 0),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderInfo(context),
                const Divider(thickness: 8, height: 8),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Submissions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildSubmissionsList(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentTask.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                'Due: ${_formatDate(_currentTask.dueDate)}',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Description',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _currentTask.description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsList(BuildContext context) {
    final assignees = _currentTask.assignees;
    // We need user names. Accessing AuthService to get cached users would be ideal.
    // simpler: using StreamBuilder for users is heavy here.
    // For now, let's use FutureBuilder once to fetch all users names.
    final authService = Provider.of<AuthService>(context, listen: false);

    return FutureBuilder<List<User>>(
      future: authService.getAllUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final allUsers = snapshot.data!;
        final userMap = {for (var u in allUsers) u.id: u};

        if (assignees.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No students assigned.'),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: assignees.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final studentId = assignees[index];
            final student = userMap[studentId];
            final name = student?.name ?? 'Unknown Student';

            final submissions = _currentTask.submissions ?? {};
            final hasSubmitted = submissions.containsKey(studentId);
            final grades = _currentTask.grades ?? {};
            final isGraded = grades.containsKey(studentId);
            final grade = isGraded ? grades[studentId] : null;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: (student?.profileImage ?? '').isNotEmpty
                    ? NetworkImage(student!.profileImage!)
                    : null,
                child: (student?.profileImage ?? '').isEmpty
                    ? Text(name.isNotEmpty ? name[0] : '?')
                    : null,
              ),
              title: Text(name),
              subtitle: Text(
                isGraded
                    ? 'Graded: ${grade?.score.toStringAsFixed(0)}/${grade?.maxScore.toStringAsFixed(0)} - ${grade?.comment ?? ""}'
                    : (hasSubmitted
                          ? 'Submitted - Needs Grading'
                          : 'Pending Submission'),
                style: TextStyle(
                  color: isGraded
                      ? Colors.teal
                      : (hasSubmitted ? Colors.orange : Colors.grey),
                  fontSize: 12,
                ),
              ),
              trailing: hasSubmitted
                  ? ElevatedButton(
                      onPressed: () {
                        List<dynamic> rawFiles = submissions[studentId] ?? [];
                        List<String> fileUrls = rawFiles.cast<String>();

                        _showProfessorGradingDialog(
                          context,
                          _currentTask,
                          studentId,
                          fileUrls,
                          isGraded,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isGraded
                            ? Colors.grey[300]
                            : Colors.blue,
                        foregroundColor: isGraded
                            ? Colors.black87
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: Text(isGraded ? 'View' : 'Grade'),
                    )
                  : const Text(
                      'Not Submitted',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
            );
          },
        );
      },
    );
  }

  void _showProfessorGradingDialog(
    BuildContext context,
    Task task,
    String studentId,
    List<String> fileUrls,
    bool isGraded,
  ) {
    final scoreController = TextEditingController();
    final feedbackController = TextEditingController();

    if (isGraded && task.grades != null && task.grades![studentId] != null) {
      final g = task.grades![studentId]!;
      scoreController.text = g.score.toString();
      feedbackController.text = g.comment ?? '';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isGraded ? 'Submission Details' : 'Grade Submission'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attachments:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (fileUrls.isEmpty)
                  const Text('No files attached.')
                else
                  ...fileUrls.map(
                    (url) => InkWell(
                      onTap: () => launchUrl(Uri.parse(url)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.attachment,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                url.split('/').last,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Reflections/Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.submissionNotes?[studentId] ?? 'No notes provided.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                if (isGraded) const Divider(),
                if (isGraded)
                  if (isGraded)
                    Text(
                      'Grade: ${scoreController.text} / 100\nFeedback: ${feedbackController.text}',
                    ),
                if (!isGraded) ...[
                  const Divider(),
                  TextField(
                    controller: scoreController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Score (0-100)',
                    ),
                  ),
                  TextField(
                    controller: feedbackController,
                    decoration: const InputDecoration(
                      labelText: 'Feedback (Optional)',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!isGraded)
              TextButton(
                onPressed: () {
                  // Reject Logic
                  Navigator.pop(dialogContext);
                  _showRejectDialog(context, task.id);
                },
                child: const Text(
                  'Reject (Resubmit)',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            if (!isGraded)
              ElevatedButton(
                onPressed: () async {
                  final score = double.tryParse(scoreController.text) ?? 0.0;

                  if (score > 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Score cannot exceed 100')),
                    );
                    return;
                  }

                  final feedback = feedbackController.text;

                  final grade = Grade(
                    score: score,
                    maxScore: 100.0,
                    comment: feedback,
                    gradedAt: DateTime.now(),
                    gradedBy: widget.user.id,
                  );

                  await Provider.of<FirestoreTaskService>(
                    context,
                    listen: false,
                  ).gradeTask(task.id, studentId, grade);

                  if (context.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Submit Grade'),
              ),
          ],
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context, String taskId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Submission'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Enter reason for rejection...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                Provider.of<FirestoreTaskService>(
                  context,
                  listen: false,
                ).rejectTask(taskId, reasonController.text);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
