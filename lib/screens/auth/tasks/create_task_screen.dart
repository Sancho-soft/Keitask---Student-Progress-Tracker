// keitask_management/lib/screens/auth/tasks/create_task_screen.dart (UPDATED - Uses Firebase Users)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart' as app_models;
import '../../../services/firestore_task_service.dart';
import '../../../services/auth_service.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);

  final List<String> _selectedAssigneeIds = [];
  bool _allowMultipleAssign = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // No default selected user here. User must choose one.
  }

  // --- Date/Time Selection and Task Creation Logic (Omitting for brevity, remains the same) ---

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _createTask() async {
    final taskService = Provider.of<FirestoreTaskService>(
      context,
      listen: false,
    );
    // Simple approach: fetch users from Firestore 'users' collection for selection
    // We'll load users via a stream for the choice chips below.

    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a task title', Colors.red);
      return;
    }
    if (_selectedAssigneeIds.isEmpty) {
      _showSnackBar('Please select at least one team member', Colors.red);
      return;
    }

    setState(() => _isCreating = true);

    final args = ModalRoute.of(context)?.settings.arguments;
    final user = (args is app_models.User) ? args : null;
    final creatorId = user?.id ?? 'unknown_creator';

    final dueDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Create a single Task that contains the list of selected assignees
    final assignees = List<String>.from(_selectedAssigneeIds);
    // Try to resolve human-readable assignee names (optional)
    final authService = Provider.of<AuthService>(context, listen: false);
    List<String>? assigneeNames;
    try {
      final allUsers = await authService.getAllUsers();
      assigneeNames = allUsers
          .where((u) => assignees.contains(u.id))
          .map((u) => u.name)
          .toList();
    } catch (_) {
      assigneeNames = null;
    }

    final newTask = app_models.Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      status: 'pending',
      assignees: assignees,
      assigneeNames: assigneeNames,
      dueDate: dueDateTime,
      creator: creatorId,
    );
    await taskService.createTask(newTask);

    if (!mounted) return;

    setState(() => _isCreating = false);
    _showSnackBar(
      'Task created successfully (Pending Admin Review)',
      Colors.green,
    );
    Navigator.pop(context);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fetch Firebase users from AuthService
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New task'),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
        elevation: 0,
      ),
      body: StreamBuilder<List<app_models.User>>(
        stream: authService.getAllUsersStream(),
        builder: (context, snapshot) {
          // Filter out admin users
          final assignableUsers = (snapshot.data ?? [])
              .where((user) => user.role != 'admin')
              .toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gray Background Area for Task Title and Details
                Container(
                  color: Colors.grey[100],
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Title
                      _buildLabel('Task Title'),
                      _buildTextField(
                        controller: _titleController,
                        hint: 'Task title here',
                        isGrayBackground: true,
                      ),
                      const SizedBox(height: 24),

                      // Task Details
                      _buildLabel('Task Details'),
                      _buildTextField(
                        controller: _descriptionController,
                        hint: 'Task description here',
                        maxLines: 5,
                        isGrayBackground: true,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Assignment mode toggle
                      Row(
                        children: [
                          Switch(
                            value: _allowMultipleAssign,
                            onChanged: (val) {
                              setState(() {
                                _allowMultipleAssign = val;
                                _selectedAssigneeIds.clear();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _allowMultipleAssign
                                ? 'Multiple Assign'
                                : 'Single Assign',
                          ),
                        ],
                      ),
                      _buildLabel('Assign to'),
                      snapshot.connectionState == ConnectionState.waiting
                          ? const SizedBox(
                              height: 50,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : assignableUsers.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'No team members available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : _allowMultipleAssign
                          ? Wrap(
                              spacing: 8,
                              children: assignableUsers.map((user) {
                                final selected = _selectedAssigneeIds.contains(
                                  user.id,
                                );
                                return FilterChip(
                                  label: Text(user.name),
                                  selected: selected,
                                  onSelected: (val) {
                                    setState(() {
                                      if (val) {
                                        _selectedAssigneeIds.add(user.id);
                                      } else {
                                        _selectedAssigneeIds.remove(user.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            )
                          : DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedAssigneeIds.isNotEmpty
                                  ? _selectedAssigneeIds.first
                                  : null,
                              hint: const Text('Select a team member'),
                              items: assignableUsers.map((user) {
                                return DropdownMenuItem<String>(
                                  value: user.id,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          user.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        user.email,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedAssigneeIds
                                    ..clear()
                                    ..add(newValue!);
                                });
                              },
                              underline: Container(
                                height: 1,
                                color: Colors.grey[300],
                              ),
                            ),
                      const SizedBox(height: 24),

                      // Time & Date Pickers
                      _buildLabel('Time & Date'),
                      Row(
                        children: [
                          // Time Picker
                          Expanded(
                            child: _buildDateTimePickerBox(
                              context,
                              onTap: () => _selectTime(context),
                              icon: Icons.access_time,
                              text: _selectedTime.format(context),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Date Picker
                          Expanded(
                            child: _buildDateTimePickerBox(
                              context,
                              onTap: () => _selectDate(context),
                              icon: Icons.calendar_today,
                              text:
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            ),
                          ),
                        ],
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
                                  'Create',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildDateTimePickerBox(
    BuildContext context, {
    required VoidCallback onTap,
    required IconData icon,
    required String text,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
