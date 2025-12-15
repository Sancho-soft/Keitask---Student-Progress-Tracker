// keitask_management/lib/screens/auth/tasks/create_task_screen.dart (UPDATED - Uses Firebase Users)

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart' as app_models;
import '../../services/firestore_task_service.dart';
import '../../services/auth_service.dart';
import 'package:keitask_management/models/task_model.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/storage_service.dart';
import 'dart:io';

class CreateTaskScreen extends StatefulWidget {
  final bool adminCreate;
  final app_models.User? user;
  final List<String>? initialAssignees; // New parameter

  const CreateTaskScreen({
    super.key,
    this.adminCreate = false,
    this.user,
    this.initialAssignees,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final List<String> _selectedAssigneeIds = [];
  // Allow users to suggest assignees (when non-admin submits a pending task)
  final TextEditingController _requestedAssigneesController =
      TextEditingController();
  bool _allowMultipleAssign = false;
  bool _assignToAll = false;
  bool _isCreating = false;

  // Attachments
  final List<PlatformFile> _pickedFiles = [];

  late Stream<List<app_models.User>> _usersStream;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _usersStream = authService.getAllUsersStream();

    if (widget.initialAssignees != null &&
        widget.initialAssignees!.isNotEmpty) {
      _selectedAssigneeIds.addAll(widget.initialAssignees!);
      if (widget.initialAssignees!.length > 1) {
        _allowMultipleAssign = true;
      }
    }
  }

  // --- Date/Time Selection and Task Creation Logic (Omitting for brevity, remains the same) ---

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    // Allow today by resetting time to midnight for the start range
    final firstDate = DateTime(now.year, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(firstDate)
          ? firstDate
          : _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(2030), // Extended range
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);

      // Post-check: If they switched to Today, and the current _selectedTime is already passed,
      // warn them or let the _createTask validation handle it?
      // Better UX: check immediately.
      if (picked.year == now.year &&
          picked.month == now.month &&
          picked.day == now.day) {
        final currentMinutes = now.hour * 60 + now.minute;
        final selectedMinutes = _selectedTime.hour * 60 + _selectedTime.minute;
        if (selectedMinutes <= currentMinutes) {
          _showSnackBar(
            'Note: Selected time is in the past. Please update time.',
            Colors.orange,
          );
          // Optional: Auto-bump time?
          // setState(() => _selectedTime = TimeOfDay.fromDateTime(now.add(Duration(minutes: 5))));
        }
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    // Current selected combined DateTime
    DateTime initialDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // We update this temporary variable as the user scrolls
    DateTime tempPickedDateTime = initialDateTime;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Time',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Picker
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: initialDateTime,
                  use24hFormat: false,
                  onDateTimeChanged: (DateTime newDate) {
                    // Update the temp date, but KEEP the originally selected Day/Month/Year
                    // (The time picker often defaults to 'today' or '2001' depending on implementation,
                    // but we just want the time components)
                    tempPickedDateTime = DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      newDate.hour,
                      newDate.minute,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    // VALIDATION LOGIC after selection is confirmed (sheet closed)
    final now = DateTime.now();
    if (tempPickedDateTime.isBefore(now)) {
      _showSnackBar(
        'Please select a future time. Selection Reset.',
        Colors.red,
      );
      // We do not update _selectedTime, essentially filtering the invalid input
    } else {
      setState(() {
        _selectedTime = TimeOfDay.fromDateTime(tempPickedDateTime);
      });
    }
  }

  // --- File Picker Logic ---
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt',
        ],
      );

      if (result != null) {
        setState(() {
          _pickedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking files: $e', Colors.red);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
    });
  }

  Future<void> _createTask() async {
    final taskService = Provider.of<FirestoreTaskService>(
      context,
      listen: false,
    );
    final authService = Provider.of<AuthService>(context, listen: false);
    // Simple approach: fetch users from Firestore 'users' collection for selection
    // We'll load users via a stream for the choice chips below.

    final args = ModalRoute.of(context)?.settings.arguments;
    app_models.User? user = widget.user;
    bool adminCreate = widget.adminCreate;
    if (args is Map) {
      if (args['user'] is app_models.User) {
        user = args['user'] as app_models.User;
      }
      if (args['adminCreate'] is bool) {
        adminCreate = args['adminCreate'] as bool;
      }
    } else if (args is app_models.User) {
      user = args;
    }

    // Treat professors as admins for task creation purposes
    if (user?.role.toLowerCase() == 'professor' ||
        user?.role.toLowerCase() == 'admin') {
      adminCreate = true;
    }

    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a task title', Colors.red);
      return;
    }
    // allow non-admins to create pending tasks (no early return)
    // Only enforce assignee selection for admins
    // Only enforce assignee selection for admins if not assigning to all
    if (adminCreate && !_assignToAll && _selectedAssigneeIds.isEmpty) {
      _showSnackBar('Please select at least one team member', Colors.red);
      return;
    }

    setState(() => _isCreating = true);

    // args, user, and adminCreate already determined above
    final creatorId = user?.id ?? 'unknown_creator';

    // 1. Upload Attachments Logic
    List<String> attachmentUrls = [];
    if (_pickedFiles.isNotEmpty) {
      // Show upload status
      // Note: In a real app we might want a separate robust progress,
      // but here we just block the submit button with _isCreating state.
      // We can iterate and upload.
      final storageService = StorageService();
      // Generate a temporary ID if we want, or just use a timestamp for folder
      final now = DateTime.now();
      final tempTaskId = now.millisecondsSinceEpoch.toString();
      final folderPath = 'tasks/${now.year}/$tempTaskId';

      for (var file in _pickedFiles) {
        if (file.path != null) {
          final url = await storageService.uploadFile(
            File(file.path!),
            folder: folderPath, // Organized by year and task
          );
          if (url != null) {
            // Append original file name for display purposes
            final namedUrl =
                '$url?originalName=${Uri.encodeComponent(file.name)}';
            attachmentUrls.add(namedUrl);
          } else {
            // Track failures
            // In a real app we might retry or structured error handling
            // For now we just wont add it.
            debugPrint('Failed to upload file: ${file.name}');
          }
        }
      }
    }

    final dueDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    int failedCount = _pickedFiles.length - attachmentUrls.length;
    if (failedCount > 0) {
      _showSnackBar(
        '$failedCount file(s) failed to upload. Task created with ${attachmentUrls.length} attachments.',
        Colors.orange,
      );
    } else {
      _showSnackBar('Task created successfully', Colors.green);
    }

    if (dueDateTime.isBefore(DateTime.now())) {
      _showSnackBar('Due time must be in the future', Colors.red);
      setState(() => _isCreating = false);
      return;
    }

    // Create a single Task that contains the list of selected assignees
    List<String> assignees = [];

    if (adminCreate) {
      if (_assignToAll) {
        // Fetch all students
        try {
          final allUsers = await authService.getAllUsers();
          assignees = allUsers
              .where((u) => u.role != 'admin' && u.role != 'professor')
              .map((u) => u.id)
              .toList();
        } catch (e) {
          // print('Error fetching all users: $e');
        }
      } else {
        assignees = List<String>.from(_selectedAssigneeIds);
      }
    }

    // Try to resolve human-readable assignee names (optional)
    List<String>? assigneeNames;
    try {
      if (assignees.isNotEmpty) {
        final allUsers = await authService.getAllUsers();
        // Map assignees to names in the SAME ORDER as the IDs
        assigneeNames = assignees.map((id) {
          final user = allUsers.firstWhere(
            (u) => u.id == id,
            orElse: () => app_models.User(
              id: id,
              email: '',
              name: 'Unknown',
              role: 'user',
            ),
          );
          return user.name;
        }).toList();
      }
    } catch (e) {
      // print('Error fetching assignee names: $e');
      assigneeNames = null;
    }

    // Determine initial status
    // Admins: 'assigned' (immediate assignment)
    // Professors: 'pending_approval' (needs admin review)
    // Others (if any): 'pending'
    String initialStatus = 'pending';
    final userRole = user?.role.toLowerCase();
    if (userRole == 'admin' || userRole == 'professor') {
      initialStatus = 'assigned';
    }

    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      status: initialStatus,
      assignees: assignees,
      assigneeNames: assigneeNames,
      dueDate: dueDateTime,
      creator: creatorId,
      attachments: attachmentUrls, // Add attachments
    );
    await taskService.createTask(newTask);

    if (!mounted) return;

    setState(() => _isCreating = false);
    // Success message moved up to handle partial failures logic
    // _showSnackBar('Task created successfully', Colors.green);
    Navigator.pop(context);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating, // Floating behavior
        margin: const EdgeInsets.all(16), // Margin for floating look
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    // Removed controller since non-admin request flow was removed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fetch Firebase users from AuthService

    final args = ModalRoute.of(context)?.settings.arguments;
    app_models.User? user = widget.user;
    bool adminCreate = widget.adminCreate;

    if (args is Map) {
      if (args['user'] is app_models.User) {
        user = args['user'] as app_models.User;
      }
      if (args['adminCreate'] is bool) {
        adminCreate = args['adminCreate'] as bool;
      }
    } else if (args is app_models.User) {
      user = args;
    }

    // Treat professors as admins for task creation purposes
    if (user?.role.toLowerCase() == 'professor' ||
        user?.role.toLowerCase() == 'admin') {
      adminCreate = true;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New task'),
        elevation: 0,
      ),
      body: StreamBuilder<List<app_models.User>>(
        stream: _usersStream,
        builder: (context, snapshot) {
          // Filter out admin users, professors, and the current user
          final assignableUsers = (snapshot.data ?? [])
              .where(
                (u) =>
                    u.role != 'admin' &&
                    u.role != 'professor' &&
                    u.id != widget.user?.id,
              )
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Task Title'),
                _buildTextField(
                  controller: _titleController,
                  hint: 'Enter task title',
                  isGrayBackground: false,
                ),
                const SizedBox(height: 24),

                _buildLabel('Description'),
                _buildTextField(
                  controller: _descriptionController,
                  hint: 'Enter task details...',
                  maxLines: 5,
                  isGrayBackground: false,
                ),
                const SizedBox(height: 24),

                // Assignment Section
                if (adminCreate) ...[
                  Row(
                    children: [
                      // Assign to All Toggle
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _assignToAll,
                          onChanged: (val) {
                            setState(() {
                              _assignToAll = val;
                              if (val) {
                                _selectedAssigneeIds.clear();
                                _allowMultipleAssign =
                                    false; // Disable specific selection
                              }
                            });
                          },
                          activeThumbColor: Colors.white,
                          activeTrackColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Assign to All Students',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if (!_assignToAll) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: _allowMultipleAssign,
                            onChanged: (val) {
                              setState(() {
                                _allowMultipleAssign = val;
                                _selectedAssigneeIds.clear();
                              });
                            },
                            activeThumbColor: Colors.white,
                            activeTrackColor: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _allowMultipleAssign
                              ? 'Multiple Assign'
                              : 'Single Assign',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!_assignToAll) ...[
                    const SizedBox(height: 12),
                    _buildLabel('Assign to'),
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) ...[
                      const Center(child: CircularProgressIndicator()),
                    ] else if (assignableUsers.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: const Text(
                          'No team members available to assign.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ] else ...[
                      if (_allowMultipleAssign) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: assignableUsers.isEmpty
                              ? const Text('No users found')
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: assignableUsers.map((user) {
                                    final selected = _selectedAssigneeIds
                                        .contains(user.id);
                                    return FilterChip(
                                      label: Text(user.name),
                                      selected: selected,
                                      onSelected: (val) {
                                        setState(() {
                                          if (val) {
                                            _selectedAssigneeIds.add(user.id);
                                          } else {
                                            _selectedAssigneeIds.remove(
                                              user.id,
                                            );
                                          }
                                        });
                                      },
                                      avatar: CircleAvatar(
                                        backgroundImage:
                                            (user.profileImage ?? '').isNotEmpty
                                            ? NetworkImage(user.profileImage!)
                                            : null,
                                        child: (user.profileImage ?? '').isEmpty
                                            ? Text(
                                                user.name.isNotEmpty
                                                    ? user.name[0]
                                                    : '?',
                                              )
                                            : null,
                                      ),
                                      selectedColor: Colors.blue[100],
                                      checkmarkColor: Colors.blue,
                                    );
                                  }).toList(),
                                ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedAssigneeIds.isNotEmpty
                                  ? _selectedAssigneeIds.first
                                  : null,
                              hint: const Text('Select a team member'),
                              icon: const Icon(Icons.arrow_drop_down),
                              items: assignableUsers.map((user) {
                                return DropdownMenuItem<String>(
                                  value: user.id,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundImage:
                                            (user.profileImage ?? '').isNotEmpty
                                            ? NetworkImage(user.profileImage!)
                                            : null,
                                        child: (user.profileImage ?? '').isEmpty
                                            ? Text(
                                                user.name.isNotEmpty
                                                    ? user.name[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              user.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedAssigneeIds
                                      ..clear()
                                      ..add(newValue);
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ] else ...[
                  // Non-admin suggestion field
                  _buildLabel('Suggest Assignees (Optional)'),
                  TextField(
                    controller: _requestedAssigneesController,
                    decoration: InputDecoration(
                      hintText: 'e.g., John Doe, Jane Smith',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                const SizedBox(height: 24),

                // --- Attachments Section ---
                _buildLabel('Attachments (Optional)'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50], // Light gray background
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_pickedFiles.isNotEmpty)
                        Column(
                          children: _pickedFiles.asMap().entries.map((entry) {
                            final index = entry.key;
                            final file = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.attach_file,
                                  color: Colors.blue,
                                ),
                                title: Text(
                                  file.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeFile(index),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add File (PDF, DOC, Images)'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Date & Time Selection
                const SizedBox(height: 16),
                _buildLabel('Due Date & Time'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.blue.withAlpha(50)),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDateTimePickerRow(
                        context,
                        title: 'Select Date',
                        value:
                            '${_selectedDate.day} ${_getMonthName(_selectedDate.month).substring(0, 3)} ${_selectedDate.year}',
                        icon: Icons.calendar_today_rounded,
                        onTap: () => _selectDate(context),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      _buildDateTimePickerRow(
                        context,
                        title: 'Select Time',
                        value: _selectedTime.format(context),
                        icon: Icons.access_time_rounded,
                        onTap: () => _selectTime(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      elevation: 4,
                      shadowColor: Colors.blue.withAlpha(100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Create Task',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper method for month name
  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Widget _buildDateTimePickerRow(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(20),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets (Omitting for brevity, remain the same) ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool isGrayBackground = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: isGrayBackground,
        fillColor: isGrayBackground ? Colors.white : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
