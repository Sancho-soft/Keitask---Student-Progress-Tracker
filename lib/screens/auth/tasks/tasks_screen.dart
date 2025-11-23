// keitask_management/lib/screens/auth/tasks/tasks_screen.dart (MODIFIED FOR USER UI)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../services/task_service.dart';
import '../../../services/firestore_task_service.dart';
import 'edit_task_screen.dart'; // Import to use in the action sheet

class TasksScreen extends StatefulWidget {
  final User? user;

  const TasksScreen({super.key, this.user});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  DateTime _selectedDate = DateTime.now();
  int _selectedDayIndex = DateTime.now().weekday % 7; // 0 = Sunday
  bool _showAllTasks = false; // Toggle to show all tasks or just today

  // Note: we'll filter streamed tasks in the StreamBuilder below.

  // --- NEW: Task Action Context Menu (Modal Bottom Sheet) ---
  void _showTaskActionsSheet(
    BuildContext context,
    Task task,
    TaskService taskService,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final firestore = Provider.of<FirestoreTaskService>(
          context,
          listen: false,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                task.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
              ),
              title: const Text('Finish Task'),
              onTap: () async {
                // Prevent marking already completed/approved tasks
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                if (task.status == 'completed' || task.status == 'approved') {
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Task is already completed.')),
                  );
                  return;
                }
                await firestore.markTaskComplete(task.id);
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Task marked as COMPLETED.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Task'),
              onTap: () {
                Navigator.pop(context); // Close sheet
                // Navigate to the dedicated Edit Task form
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditTaskScreen(task: task),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Task'),
              onTap: () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await firestore.deleteTask(task.id);
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Task deleted.')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep TaskService available in widget tree for helper functions; we access it inline where needed.
    final args = ModalRoute.of(context)?.settings.arguments;
    final routeUser = (args is User) ? args : null;
    final effectiveUser = widget.user ?? routeUser;
    final isAdmin = (effectiveUser is User) && effectiveUser.role == 'admin';
    final firestore = Provider.of<FirestoreTaskService>(context);

    // Get current month/year for header
    final monthYear =
        '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}';
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(monthYear),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Selector (Matching Figma Design)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (index) {
                  final isSelected = index == _selectedDayIndex;
                  final dayName = daysOfWeek[index];
                  // Calculate the day number for this week
                  final today = DateTime.now();
                  final startOfWeek = today.subtract(
                    Duration(days: today.weekday % 7),
                  );
                  final day = startOfWeek.add(Duration(days: index));

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDayIndex = index;
                        _selectedDate = DateTime(day.year, day.month, day.day);
                      });
                    },
                    child: Container(
                      width: 50,
                      margin: EdgeInsets.only(
                        left: index == 0 ? 16 : 4,
                        right: 4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Text(
                            dayName.toUpperCase().substring(0, 3),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.only(
              top: 16.0,
              left: 16.0,
              right: 16.0,
              bottom: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Task',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    // Toggle button for all tasks
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showAllTasks = !_showAllTasks),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _showAllTasks ? Colors.blue : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _showAllTasks ? 'All' : 'Today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _showAllTasks
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Notification Icon
                    Icon(
                      Icons.notifications_none,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Task List (real-time from Firestore)
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: firestore.tasksStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allTasks = snapshot.data ?? [];

                // If we don't have an effective user, show empty state
                if (effectiveUser == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No user selected',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Filter tasks by assignee/creator and selected date (or all if toggled)
                final userTasks = allTasks.where((task) {
                  final matchesUser =
                      task.assignee == effectiveUser.id ||
                      task.creator == effectiveUser.id;

                  // If showing all tasks, only filter by user
                  if (_showAllTasks) {
                    return matchesUser;
                  }

                  // Otherwise filter by both user and date
                  final matchesDate =
                      task.dueDate.year == _selectedDate.year &&
                      task.dueDate.month == _selectedDate.month &&
                      task.dueDate.day == _selectedDate.day;
                  return matchesUser && matchesDate;
                }).toList();

                if (userTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _showAllTasks
                              ? 'No tasks found'
                              : 'No tasks found for ${_formatDateDay(_selectedDate)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: userTasks.length,
                  itemBuilder: (context, index) {
                    final task = userTasks[index];
                    return _buildTaskCard(
                      context,
                      task,
                      Provider.of<TaskService>(context),
                    );
                  },
                );
              },
            ),
          ),

          // New Task Button (Matching Figma - Centered)
          if (!isAdmin)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/create-task',
                      arguments: effectiveUser,
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.blue),
                  label: const Text(
                    'New task',
                    style: TextStyle(color: Colors.blue),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      // NOTE: BottomNavigationBar is handled in dashboard_screen.dart
    );
  }

  // --- Task Card Widget (Matching Figma Task Interface) ---
  Widget _buildTaskCard(
    BuildContext context,
    Task task,
    TaskService taskService,
  ) {
    // Determine the color/icon based on status
    final bool isCompleted =
        task.status == 'completed' || task.status == 'approved';
    final Color iconColor = isCompleted ? Colors.green : Colors.blue;
    final IconData statusIcon = isCompleted
        ? Icons.check_circle_outline
        : Icons.circle;

    // Calculate if task is overdue
    final now = DateTime.now();
    final isOverdue = !isCompleted && task.dueDate.isBefore(now);
    final daysUntilDue = task.dueDate.difference(now).inDays;

    // Generate status text based on task state and due date
    String getTaskStatus() {
      if (isCompleted) {
        if (task.status == 'approved') return 'Approved';
        return 'Completed';
      }
      if (task.status == 'rejected') return 'Rejected';
      if (task.status == 'pending') return 'Pending Review';
      if (isOverdue) return 'Overdue';
      if (daysUntilDue == 0) return 'Due Today';
      if (daysUntilDue == 1) return 'Due Tomorrow';
      return 'Ongoing';
    }

    final statusText = getTaskStatus();
    final statusColor = isCompleted
        ? Colors.green
        : (isOverdue
              ? Colors.red
              : (task.status == 'rejected' ? Colors.orange : Colors.blue));

    return GestureDetector(
      onTap: () => _showTaskActionsSheet(context, task, taskService),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha((0.1 * 255).round()),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Icon (Left)
            Icon(statusIcon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            // Task Details (Middle)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatDateDay(task.dueDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha((0.15 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions Icon (Right)
            Icon(Icons.bookmark_border, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

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

  String _formatDateDay(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month).substring(0, 3)}';
  }
}
