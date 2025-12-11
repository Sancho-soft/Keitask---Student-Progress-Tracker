import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_task_service.dart';
// Unused imports removed
import 'professor_task_detail_screen.dart'; // We will create this next

class ProfessorTasksScreen extends StatefulWidget {
  final User user;

  const ProfessorTasksScreen({super.key, required this.user});

  @override
  State<ProfessorTasksScreen> createState() => _ProfessorTasksScreenState();
}

class _ProfessorTasksScreenState extends State<ProfessorTasksScreen> {
  String _searchQuery = '';
  String _selectedFilter =
      'All'; // All, Pending Approval, Completed, Resubmitted
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreTaskService>(context);

    return Scaffold(
      body: Column(
        children: [
          // Header with Search
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Tasks',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending Approval'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed'),
                      const SizedBox(width: 8),
                      // _buildFilterChip('Resubmitted'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Task List
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: firestoreService.tasksStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState('No tasks found.');
                }

                // Filter Tasks
                final allTasks = snapshot.data!;
                final myTasks = allTasks.where((task) {
                  // Professors see tasks they created OR are assigned to (unlikely but possible)
                  return task.creator == widget.user.id ||
                      task.assignees.contains(widget.user.id);
                }).toList();

                if (myTasks.isEmpty) {
                  return _buildEmptyState(
                    'You haven\'t created any tasks yet.',
                  );
                }

                // Apply Search & Status Filters
                final filteredTasks = myTasks.where((task) {
                  // Search
                  final matchesSearch = task.title.toLowerCase().contains(
                    _searchQuery,
                  );
                  if (!matchesSearch) return false;

                  // Status Filter Calculation
                  if (_selectedFilter == 'All') return true;

                  // Logic for "Pending Approval" (Needs Grading)
                  // If submissions exist that are NOT in grades map
                  final submissions = task.submissions ?? {};
                  final grades = task.grades ?? {};
                  bool needsGrading = false;
                  for (var studentId in submissions.keys) {
                    if (!grades.containsKey(studentId)) {
                      needsGrading = true;
                      break;
                    }
                  }

                  if (_selectedFilter == 'Pending Approval') {
                    return needsGrading;
                  }

                  if (_selectedFilter == 'Completed') {
                    // Check if status is finalized or all graded
                    return task.status == 'approved' ||
                        task.status == 'completed';
                  }

                  return true;
                }).toList();

                if (filteredTasks.isEmpty) {
                  return _buildEmptyState('No tasks match your filter.');
                }

                // Sort by Latest Created
                filteredTasks.sort((a, b) => b.id.compareTo(a.id));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    return _buildProfessorTaskCard(filteredTasks[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() => _selectedFilter = label);
      },
      backgroundColor: Theme.of(context).cardColor,
      selectedColor: Colors.teal.withAlpha(50),
      checkmarkColor: Colors.teal,
      labelStyle: TextStyle(
        color: isSelected ? Colors.teal : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.teal : Colors.grey.withAlpha(50),
        ),
      ),
    );
  }

  Widget _buildProfessorTaskCard(Task task) {
    // Calculate Stats
    final totalAssignees = task.assignees.length;
    final submissions = task.submissions?.length ?? 0;
    final graded = task.grades?.length ?? 0;
    final pending = submissions - graded;

    bool needsAttention = pending > 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProfessorTaskDetailScreen(task: task, user: widget.user),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          // Highlight card if it needs attention
          border: needsAttention
              ? Border.all(color: Colors.orange.withAlpha(100), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
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
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (needsAttention)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$pending Needs Grading',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  Icons.group,
                  '$totalAssignees Assigned',
                  Colors.blue,
                ),
                _buildStatItem(
                  Icons.upload_file,
                  '$submissions Submitted',
                  Colors.purple,
                ),
                _buildStatItem(Icons.grade, '$graded Graded', Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
