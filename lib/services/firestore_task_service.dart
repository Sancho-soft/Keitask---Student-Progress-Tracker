import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart' as app_models;

class FirestoreTaskService extends ChangeNotifier {
  Future<void> resubmitTask(String taskId) async {
    await _tasksRef.doc(taskId).update({
      'status': 'resubmitted',
      'rejectionReason': null,
    });
    notifyListeners();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _tasksRef => _firestore.collection('tasks');

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
    await _tasksRef.doc(task.id).set(task.toJson());
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
      'status': 'approved',
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

  Future<void> markTaskComplete(String taskId) async {
    await _tasksRef.doc(taskId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'rejectionReason': null,
    });
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksRef.doc(taskId).delete();
    notifyListeners();
  }
}
