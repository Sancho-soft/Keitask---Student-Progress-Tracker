import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreNotificationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createBroadcastNotification(String title, String body) async {
    // 1. Get all users
    final usersSnap = await _firestore.collection('users').get();

    // 2. Create a batch
    WriteBatch batch = _firestore.batch();
    int batchCount = 0;

    for (var doc in usersSnap.docs) {
      final userId = doc.id;
      final notifRef = _firestore.collection('notifications').doc();

      batch.set(notifRef, {
        'recipientId': userId,
        'title': title,
        'body': body,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'broadcast',
      });

      batchCount++;

      // Commit batch every 500 operations (Firestore limit)
      if (batchCount >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        batchCount = 0;
      }
    }

    // Commit remaining
    if (batchCount > 0) {
      await batch.commit();
    }

    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
    notifyListeners();
  }
}
