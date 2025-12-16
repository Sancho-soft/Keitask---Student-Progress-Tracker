import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter/cupertino.dart';
import 'package:keitask_management/models/task_model.dart';
import '../../models/user_model.dart';
import '../../models/grade_model.dart';
import '../../services/firestore_task_service.dart';
import '../../services/auth_service.dart';
import '../../utils/attachment_helper.dart';

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
          appBar: AppBar(
            title: const Text('Task Details'),
            elevation: 0,
            actions: [
              IconButton(
                icon: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 16,
                  child: Icon(Icons.edit, color: Colors.white, size: 18),
                ),
                onPressed: () => _showEditTaskDialog(context, _currentTask),
              ),
              const SizedBox(width: 8),
            ],
          ),
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
          // Attachments Section
          if (_currentTask.attachments != null &&
              _currentTask.attachments!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Attachments',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _currentTask.attachments!.length,
                itemBuilder: (context, index) {
                  final url = _currentTask.attachments![index];
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
                    onTap: () => AttachmentHelper.openAttachment(context, url),
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
                                : (isImage ? Icons.image : Icons.description),
                            color: isPdf
                                ? Colors.red
                                : (isImage ? Colors.purple : Colors.blue),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
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
          ],
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

                        _showProfessorGradingDialog(
                          context,
                          _currentTask,
                          studentId,
                          rawFiles,
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
    List<dynamic> files,
    bool isGraded,
  ) {
    final scoreController = TextEditingController();
    final feedbackController = TextEditingController();

    if (isGraded && task.grades != null && task.grades![studentId] != null) {
      final g = task.grades![studentId]!;
      scoreController.text = g.score.toString();
      feedbackController.text = g.comment ?? '';
    }

    final submissionTime = task.completionStatus?[studentId];
    String? formattedSubmissionTime;
    if (submissionTime != null) {
      final dt = DateTime.tryParse(submissionTime as String);
      if (dt != null) {
        formattedSubmissionTime =
            '${dt.day}/${dt.month}/${dt.year} ${dt.hour > 12 ? dt.hour - 12 : dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isGraded ? 'Submission Details' : 'Grade Submission'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attachments:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (formattedSubmissionTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Submitted on: \$formattedSubmissionTime',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  if (files.isEmpty)
                    const Text('No files attached.')
                  else
                    ...files.map((fileItem) {
                      String url;
                      String name;

                      if (fileItem is String) {
                        url = fileItem;
                        name = url.split('/').last.split('?').first;
                      } else if (fileItem is Map) {
                        url = fileItem['url'] ?? '';
                        name = fileItem['name'] ?? 'Unknown File';
                      } else {
                        return const SizedBox.shrink();
                      }

                      if (url.isEmpty) return const SizedBox.shrink();

                      final lower = url.toLowerCase().split('?').first;
                      final isImage =
                          lower.endsWith('.jpg') ||
                          lower.endsWith('.jpeg') ||
                          lower.endsWith('.png') ||
                          lower.endsWith('.webp') ||
                          lower.endsWith('.gif');
                      final isPdf = lower.endsWith('.pdf');
                      final fileName = name;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () =>
                              AttachmentHelper.openAttachment(context, url),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isImage
                                          ? Icons.image
                                          : (isPdf
                                                ? Icons.picture_as_pdf
                                                : Icons.insert_drive_file),
                                      size: 20,
                                      color: isImage
                                          ? Colors.purple
                                          : (isPdf ? Colors.red : Colors.blue),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        fileName,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.open_in_new,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                                if (isImage) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      url,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, error, stack) =>
                                          Container(
                                            height: 150,
                                            color: Colors.grey[200],
                                            alignment: Alignment.center,
                                            child: const Text('Image Error'),
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
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
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            if (!isGraded) ...[
              // Row 1: Submit Grade button (full width)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final score = double.tryParse(scoreController.text) ?? 0.0;

                    if (score < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Score cannot be negative'),
                        ),
                      );
                      return;
                    }

                    if (score > 100) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Score cannot exceed 100'),
                        ),
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
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Submit Grade'),
                ),
              ),
              const SizedBox(height: 8),
              // Row 2: Reject and Close buttons (side by side)
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        // Reject Logic
                        Navigator.pop(dialogContext);
                        _showRejectDialog(context, task.id);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Reject (Resubmit)',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // For graded submissions, just show Close button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
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

  void _showEditTaskDialog(BuildContext context, Task task) {
    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description);
    DateTime selectedDate = task.dueDate;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(task.dueDate);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Task Details'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Due Date'),
                        subtitle: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (BuildContext builder) {
                              return SizedBox(
                                height: 300,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Select Date',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Done'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: CupertinoDatePicker(
                                        mode: CupertinoDatePickerMode.date,
                                        initialDateTime: selectedDate,
                                        minimumDate: DateTime.now(),
                                        maximumDate: DateTime(2100),
                                        onDateTimeChanged: (DateTime newDate) {
                                          setState(
                                            () => selectedDate = newDate,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('Due Time'),
                        subtitle: Text(selectedTime.format(context)),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (BuildContext builder) {
                              return SizedBox(
                                height: 300,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Select Time',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Done'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: CupertinoDatePicker(
                                        mode: CupertinoDatePickerMode.time,
                                        initialDateTime: DateTime(
                                          selectedDate.year,
                                          selectedDate.month,
                                          selectedDate.day,
                                          selectedTime.hour,
                                          selectedTime.minute,
                                        ),
                                        use24hFormat: false,
                                        onDateTimeChanged: (DateTime newDate) {
                                          setState(
                                            () => selectedTime =
                                                TimeOfDay.fromDateTime(newDate),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;

                    final newDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    await Provider.of<FirestoreTaskService>(
                      context,
                      listen: false,
                    ).updateTaskDetails(
                      task.id,
                      titleController.text.trim(),
                      descController.text.trim(),
                      newDateTime,
                    );

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Task updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
