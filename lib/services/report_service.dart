import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new report
  Future<void> createReport({
    required User user,
    required String title,
    required String description,
    required String type,
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': user.id,
      'reporterName': user.name,
      'reporterEmail': user.email,
      'title': title,
      'description': description,
      'type': type,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream of all reports (for Admin)
  Stream<List<Report>> getReportsStream() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Report.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  // Update report status
  Future<void> updateReportStatus(String reportId, String newStatus) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': newStatus,
    });
  }
}
