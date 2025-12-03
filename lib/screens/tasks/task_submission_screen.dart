import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_task_service.dart';
import '../../services/storage_service.dart';

class TaskSubmissionScreen extends StatefulWidget {
  final Task task;
  final User user;

  const TaskSubmissionScreen({
    super.key,
    required this.task,
    required this.user,
  });

  @override
  State<TaskSubmissionScreen> createState() => _TaskSubmissionScreenState();
}

class _TaskSubmissionScreenState extends State<TaskSubmissionScreen> {
  final List<PlatformFile> _pickedFiles = [];
  final TextEditingController _notesController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'zip', 'doc', 'docx'],
      );

      if (result != null) {
        setState(() {
          _pickedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
    }
  }

  Future<void> _submitTask() async {
    if (_pickedFiles.isEmpty) {
      // Allow submission without files? Maybe ask for confirmation.
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No files attached'),
          content: const Text(
            'Are you sure you want to submit without any attachments?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      if (!mounted) return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    final storageService = StorageService();
    final firestoreService = Provider.of<FirestoreTaskService>(
      context,
      listen: false,
    );
    final uploadedUrls = <String>[];

    try {
      // Upload files
      for (int i = 0; i < _pickedFiles.length; i++) {
        final file = _pickedFiles[i];
        if (file.path == null) continue;

        final url = await storageService.uploadFile(
          File(file.path!),
          onProgress: (progress) {
            // Update overall progress (simplified)
            setState(() {
              _uploadProgress = (i + progress) / _pickedFiles.length;
            });
          },
        );

        if (url != null) {
          uploadedUrls.add(url);
        }
      }

      // Submit to Firestore
      await firestoreService.submitTask(
        widget.task.id,
        widget.user.id,
        uploadedUrls,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context); // Go back to tasks list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Task'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final status = widget.task.status.toLowerCase();
    if (status == 'pending') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Task Under Review',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have already submitted this task.\nPlease wait for the professor to review it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    if (status == 'completed' || status == 'approved') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Task Completed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.task.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.task.description,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text(
            'Attachments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _pickedFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No files selected',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          TextButton(
                            onPressed: _pickFiles,
                            child: const Text('Browse Files'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _pickedFiles.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final file = _pickedFiles[index];
                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${(file.size / 1024).toStringAsFixed(1)} KB',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _pickedFiles.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (_pickedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add),
                label: const Text('Add more files'),
              ),
            ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          const Text(
            'Notes (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add any comments or notes here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isUploading)
            Column(
              children: [
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 8),
                Text(
                  'Uploading... ${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: _submitTask,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Submit Task', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }
}
