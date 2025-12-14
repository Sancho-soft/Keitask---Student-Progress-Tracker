import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import '../../models/user_model.dart'; // Task, User, Grade classes
import '../../models/grade_model.dart';
import '../../services/firestore_task_service.dart';
import '../../utils/attachment_helper.dart';

class SubmissionDetailsDialog extends StatefulWidget {
  final Task task;
  final String studentId;
  final List<String> submissionUrls;
  final User viewer;

  const SubmissionDetailsDialog({
    super.key,
    required this.task,
    required this.studentId,
    required this.submissionUrls,
    required this.viewer,
  });

  @override
  State<SubmissionDetailsDialog> createState() =>
      _SubmissionDetailsDialogState();
}

class _SubmissionDetailsDialogState extends State<SubmissionDetailsDialog> {
  final _scoreController = TextEditingController();
  final _commentController = TextEditingController();

  bool _isImage(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill if already graded
    _loadGrade();
  }

  void _loadGrade() {
    Grade? existingGrade;
    try {
      if (widget.task.grades != null &&
          widget.task.grades!.containsKey(widget.studentId)) {
        existingGrade = widget.task.grades![widget.studentId]!;
        _scoreController.text = existingGrade.score.toString();
        _commentController.text = existingGrade.comment ?? '';
      }
    } catch (e) {
      debugPrint('Error loading grade: $e');
      // We can optionally show a snackbar here if checking mounted,
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-resolve grades for display to ensure updates show immediately if pushed
    Grade? existingGrade;
    if (widget.task.grades != null &&
        widget.task.grades!.containsKey(widget.studentId)) {
      existingGrade = widget.task.grades![widget.studentId];
    }

    final isProfessor = widget.viewer.role == 'professor';
    final isRejected =
        widget.task.status == 'rejected' && widget.task.rejectionReason != null;

    return AlertDialog(
      title: Text(isProfessor ? 'Grade Submission' : 'Submission Details'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rejection Reason
              if (isRejected && !isProfessor) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    border: Border.all(color: Colors.red.withAlpha(50)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rejection Reason:',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.task.rejectionReason!),
                    ],
                  ),
                ),
              ],

              // Submission Links & Previews
              const Text(
                'Documents:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (widget.submissionUrls.isEmpty)
                const Text(
                  'No documents submitted.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ...widget.submissionUrls.map((url) {
                final isImage = _isImage(url);
                final isPdf = url.toLowerCase().contains('.pdf');
                final uri = Uri.parse(url);
                final fileName =
                    uri.queryParameters['originalName'] ??
                    url.split('/').last.split('?').first;
                final shortName = fileName.length > 30
                    ? '${fileName.substring(0, 30)}...'
                    : fileName;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    onTap: () {
                      AttachmentHelper.openAttachment(context, url);
                    },
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              isImage
                                  ? Icons.image
                                  : (isPdf
                                        ? Icons.picture_as_pdf
                                        : Icons.insert_drive_file),
                              color: isImage
                                  ? Colors.purple
                                  : (isPdf ? Colors.red : Colors.blue),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                shortName,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_new, size: 20),
                              tooltip: 'Open',
                              onPressed: () {
                                AttachmentHelper.openAttachment(context, url);
                              },
                            ),
                          ],
                        ),
                        if (isImage) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, error, stack) => Container(
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
                );
              }),
              const SizedBox(height: 16),

              // Grading Section
              if (isProfessor) ...[
                const Divider(),
                const Text(
                  'Grading',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _scoreController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Score (0-100)'),
                ),
                TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comments/Feedback',
                  ),
                  maxLines: 2,
                ),
              ] else if (existingGrade != null) ...[
                // Student View (Read Only)
                const Divider(),
                const Text(
                  'Grade Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score: ${existingGrade.score} / ${existingGrade.maxScore}',
                ),
                if (existingGrade.comment != null &&
                    existingGrade.comment!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('Feedback: ${existingGrade.comment}'),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (isProfessor)
          ElevatedButton(
            onPressed: _submitGrade,
            child: const Text('Save Grade'),
          ),
      ],
    );
  }

  Future<void> _submitGrade() async {
    final score = double.tryParse(_scoreController.text);

    if (score == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid number')));
      return;
    }

    if (score > 100) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Score cannot exceed 100')));
      return;
    }

    final grade = Grade(
      score: score,
      maxScore: 100.0,
      comment: _commentController.text,
      gradedBy: widget.viewer.id,
      gradedAt: DateTime.now(),
    );

    try {
      final firestore = Provider.of<FirestoreTaskService>(
        context,
        listen: false,
      );
      await firestore.gradeTask(widget.task.id, widget.studentId, grade);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Grade saved!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving grade: $e')));
    }
  }
}
