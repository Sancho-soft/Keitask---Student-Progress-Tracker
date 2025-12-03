import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart' as app_models;
import '../models/grade_model.dart' as app_models;

class FirestoreTaskService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _tasksRef => _firestore.collection('tasks');

  Future<void> resubmitTask(String taskId) async {
    await _tasksRef.doc(taskId).update({
      'status': 'resubmitted',
      'rejectionReason': null,
    });
    notifyListeners();
  }

  Stream<List<app_models.Task>> tasksStream() {
    return _tasksRef.snapshots().map(
      (snap) => snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        // ensure the document id is available to the model
        final merged = Map<String, dynamic>.from(data);
        merged['id'] = d.id;
        return app_models.Task.fromJson(merged);
      }).toList(),
    );
  }

  Future<List<app_models.Task>> getAllTasks() async {
    final snap = await _tasksRef.get();
    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      final merged = Map<String, dynamic>.from(data);
      merged['id'] = d.id;
      return app_models.Task.fromJson(merged);
    }).toList();
  }

  Future<void> createTask(app_models.Task task) async {
    // Persist all task fields including courseId, grades, etc.
    await _tasksRef.doc(task.id).set(task.toJson());

    // Create notifications for assignees
    final batch = _firestore.batch();
    for (var assigneeId in task.assignees) {
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'recipientId': assigneeId,
        'title': 'New Task Assigned',
        'body': 'You have been assigned a new task: ${task.title}',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'task_assigned',
        'relatedId': task.id,
      });
    }
    await batch.commit();

    notifyListeners();
  }

  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    await _tasksRef.doc(taskId).update({'status': newStatus});
    notifyListeners();
  }

  Future<void> rejectTask(String taskId, String reason) async {
    await _tasksRef.doc(taskId).update({
      'status': 'rejected',
      'rejectionReason': reason,
    });
    notifyListeners();
  }

  Future<void> approveTask(String taskId) async {
    // Approve without marking completedAt — approval is distinct from completion.
    await _tasksRef.doc(taskId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'rejectionReason': null,
    });
    notifyListeners();
  }

  Future<void> approveProfessorTask(String taskId) async {
    await _tasksRef.doc(taskId).update({
      'status': 'assigned',
      'rejectionReason': null,
    });
    notifyListeners();
  }

  Future<void> toggleBookmark(String taskId, String userId, bool add) async {
    if (add) {
      await _tasksRef.doc(taskId).update({
        'bookmarkedBy': FieldValue.arrayUnion([userId]),
      });
    } else {
      await _tasksRef.doc(taskId).update({
        'bookmarkedBy': FieldValue.arrayRemove([userId]),
      });
    }
    notifyListeners();
  }

  Future<void> markTaskComplete(
    String taskId, {
    String? completedBy,
    int rewardPoints = 10,
  }) async {
    // If completedBy is provided, we track per-user completion
    if (completedBy != null && completedBy.isNotEmpty) {
      final taskRef = _tasksRef.doc(taskId);
      final taskDoc = await taskRef.get();
      if (!taskDoc.exists) return;

      final taskData = taskDoc.data() as Map<String, dynamic>;
      final assignees = List<String>.from(taskData['assignees'] ?? []);

      // Update completion status for this user
      await taskRef.update({
        'completionStatus.$completedBy': DateTime.now().toIso8601String(),
      });

      // Award points to the user who completed the task
      final usersRef = _firestore.collection('users');
      await usersRef.doc(completedBy).update({
        'points': FieldValue.increment(rewardPoints),
      });

      // Check if all assignees have completed
      final completionStatus = Map<String, dynamic>.from(
        taskData['completionStatus'] ?? {},
      );
      completionStatus[completedBy] = DateTime.now()
          .toIso8601String(); // Add current update to local check

      bool allCompleted = true;
      if (assignees.isNotEmpty) {
        for (var assignee in assignees) {
          if (!completionStatus.containsKey(assignee)) {
            allCompleted = false;
            break;
          }
        }
      } else {
        // If no assignees, mark as completed
        allCompleted = true;
      }

      if (allCompleted) {
        await taskRef.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'rejectionReason': null,
        });
      }
    } else {
      // Fallback for legacy calls or admin overrides
      final updates = <String, Object?>{
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'rejectionReason': null,
      };
      await _tasksRef.doc(taskId).update(updates);
    }

    notifyListeners();
  }

  Future<void> submitTask(
    String taskId,
    String userId,
    List<String> fileUrls,
  ) async {
    final taskRef = _tasksRef.doc(taskId);
    final taskDoc = await taskRef.get();
    if (!taskDoc.exists) return;

    final taskData = taskDoc.data() as Map<String, dynamic>;
    final currentSubmissions = Map<String, dynamic>.from(
      taskData['submissions'] ?? {},
    );
    currentSubmissions[userId] = fileUrls;

    final currentCompletionStatus = Map<String, dynamic>.from(
      taskData['completionStatus'] ?? {},
    );
    currentCompletionStatus[userId] = DateTime.now().toIso8601String();

    // Check if all assignees have completed

    await taskRef.update({
      'submissions': currentSubmissions,
      'completionStatus': currentCompletionStatus,
      'status': 'pending', // Always set to pending for review
    });
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksRef.doc(taskId).delete();
    notifyListeners();
  }

  Future<void> gradeTask(
    String taskId,
    String studentId,
    app_models.Grade grade,
  ) async {
    final taskRef = _tasksRef.doc(taskId);
    final taskDoc = await taskRef.get();
    if (!taskDoc.exists) return;

    final taskData = taskDoc.data() as Map<String, dynamic>;
    final currentGrades = Map<String, dynamic>.from(taskData['grades'] ?? {});
    currentGrades[studentId] = grade.toJson();

    // Update the task with the new grade
    // Note: We don't necessarily mark the task as 'completed' for everyone,
    // but for the specific student it is effectively graded.
    // If you want to mark it completed for that student in 'completionStatus', you can do so.
    final currentCompletionStatus = Map<String, dynamic>.from(
      taskData['completionStatus'] ?? {},
    );
    // Ensure it's marked as completed for the student if graded
    currentCompletionStatus[studentId] = DateTime.now().toIso8601String();

    await taskRef.update({
      'grades': currentGrades,
      'completionStatus': currentCompletionStatus,
    });

    // Optionally award points to the student
    // For example, if score > passing, give points.
    // Here we just give points equal to the score for simplicity, or a fixed amount.
    if (grade.score > 0) {
      final usersRef = _firestore.collection('users');
      await usersRef.doc(studentId).update({
        'points': FieldValue.increment(grade.score.toInt()),
      });
    }

    notifyListeners();
  }
}
