// lib/services/task_service.dart (UPDATED - Firebase users managed by CreateTaskScreen via AuthService)
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class TaskService extends ChangeNotifier {
  // Cache for user names to avoid repeated lookups
  final Map<String, String> _userNameCache = {};

  // Set user name cache from Firebase users
  void setUserNames(Map<String, String> userNames) {
    _userNameCache.clear();
    _userNameCache.addAll(userNames);
  }

  Map<String, String> get userNames => _userNameCache;

  // Getter for a user's name (used by Leaderboard)
  String getUserName(String userId) {
    // Return cached name or default
    return _userNameCache[userId] ?? 'User';
  } // 1. IN-MEMORY TASK DATA STORE (Simulated Backend)

  final List<Task> _tasks = [];

  // --- READ OPERATIONS (Omitting for brevity, remains the same) ---

  List<Task> getAllTasks() => _tasks;

  List<Task> getTasksByAssignee(String userId) {
    return _tasks
        .where(
          (task) => task.assignees.contains(userId) || task.creator == userId,
        )
        .toList();
  }

  List<Task> getPendingReviewTasks() =>
      _tasks.where((task) => task.status == 'pending').toList();

  List<Task> getRecentTasks(String userId) {
    final userTasks = getTasksByAssignee(userId);
    userTasks.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return userTasks.take(3).toList();
  }

  Map<String, int> getTaskCounts() {
    return {
      'approved': _tasks.where((t) => t.status == 'approved').length,
      'pending': _tasks.where((t) => t.status == 'pending').length,
      'rejected': _tasks.where((t) => t.status == 'rejected').length,
      'resubmitted': _tasks.where((t) => t.status == 'resubmitted').length,
      'completed': _tasks.where((t) => t.status == 'completed').length,
    };
  }

  // --- CREATE/UPDATE/DELETE OPERATIONS (Omitting for brevity, remain the same) ---

  void createTask({
    required String title,
    required String description,
    String? assignee,
    List<String>? assignees,
    required DateTime dueDate,
    String? creator,
  }) {
    final resolvedAssignees =
        assignees ?? (assignee != null ? [assignee] : <String>[]);

    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      status: 'pending',
      assignees: resolvedAssignees,
      dueDate: dueDate,
      creator: creator,
    );
    _tasks.add(newTask);
    notifyListeners();
  }

  void _updateTaskStatus(
    String taskId,
    String newStatus, {
    String? rejectionReason,
  }) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final oldTask = _tasks[index];
      _tasks[index] = Task(
        id: oldTask.id,
        title: oldTask.title,
        description: oldTask.description,
        status: newStatus,
        assignees: oldTask.assignees,
        dueDate: oldTask.dueDate,
        creator: oldTask.creator,
        rejectionReason: rejectionReason,
      );
      notifyListeners();
    }
  }

  void approveTask(String taskId) => _updateTaskStatus(taskId, 'approved');
  void rejectTask(String taskId, String reason) =>
      _updateTaskStatus(taskId, 'rejected', rejectionReason: reason);
  void markTaskComplete(String taskId) =>
      _updateTaskStatus(taskId, 'completed');
  void deleteTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  // --- LEADERBOARD RESET (Admin Only) ---
  void resetLeaderboard() {
    // Mark all completed/approved tasks as pending
    for (int i = 0; i < _tasks.length; i++) {
      if (_tasks[i].status == 'completed' || _tasks[i].status == 'approved') {
        final task = _tasks[i];
        _tasks[i] = Task(
          id: task.id,
          title: task.title,
          description: task.description,
          status: 'pending',
          assignees: task.assignees,
          dueDate: task.dueDate,
          creator: task.creator,
        );
      }
    }
    notifyListeners();
  }

  Future<void> toggleBookmark(String taskId, String userId, bool add) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      // Note: This is a simplifield in-memory implementation.
      // In a real app, you'd likely update a specific 'bookmarkedBy' field or similar.
      // For now, we'll just acknowledge the call or mock it if Task model supports it.
      // Assuming Task model has 'bookmarkedBy' list:
      List<String> bookmarks = List.from(task.bookmarkedBy ?? []);
      if (add) {
        if (!bookmarks.contains(userId)) bookmarks.add(userId);
      } else {
        bookmarks.remove(userId);
      }

      _tasks[index] = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        status: task.status,
        assignees: task.assignees,
        dueDate: task.dueDate,
        creator: task.creator,
        grades: task.grades,
        submissions: task.submissions,
        submissionNotes: task.submissionNotes,
        completionStatus: task.completionStatus,
        bookmarkedBy: bookmarks,
      );
      notifyListeners();
    }
  }
}
