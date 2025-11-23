import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_task_service.dart';
import '../../../models/user_model.dart';

/// Progress detail screen: shows approved/pending/rejected/resubmitted counts
/// for the current user, a progress overview and a list of recent tasks.
class ProgressDetailScreen extends StatelessWidget {
  const ProgressDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final tasksService = Provider.of<FirestoreTaskService>(context);
    final currentUserId = auth.appUser?.id ?? auth.firebaseUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress Detail')),
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<List<Task>>(
          stream: tasksService.tasksStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final tasks = snap.data ?? [];

            // Filter tasks assigned to current user
            final myTasks = currentUserId == null
                ? <Task>[]
                : tasks.where((t) => t.assignee == currentUserId).toList();

            int approved = 0, pending = 0, rejected = 0, resubmitted = 0;
            int completedCount = 0;

            for (final t in myTasks) {
              final s = t.status.toLowerCase();
              if (s == 'approved') {
                approved++;
              } else if (s == 'pending' || s == 'assigned') {
                pending++;
              } else if (s == 'rejected') {
                rejected++;
              } else if (s == 'resubmitted' || s == 'resubmit') {
                resubmitted++;
              }

              if (s == 'completed' || s == 'approved') completedCount++;
            }

            final total = myTasks.length;
            final percent = total == 0 ? 0.0 : (completedCount / total);

            // Recent tasks sorted by date (completedAt or dueDate)
            myTasks.sort((a, b) {
              final da = a.completedAt ?? a.dueDate;
              final db = b.completedAt ?? b.dueDate;
              return db.compareTo(da);
            });

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top 4 status cards (grid)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _statusCard(
                        context,
                        'Approved',
                        approved,
                        Colors.green.shade200,
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _statusCard(
                        context,
                        'Pending',
                        pending,
                        Colors.orange.shade100,
                        Icons.schedule,
                        Colors.orange,
                      ),
                      _statusCard(
                        context,
                        'Rejected',
                        rejected,
                        Colors.red.shade100,
                        Icons.cancel,
                        Colors.red,
                      ),
                      _statusCard(
                        context,
                        'Resubmitted',
                        resubmitted,
                        Colors.purple.shade100,
                        Icons.refresh,
                        Colors.purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const Text(
                    'Progress Overview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Task Completion',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '${(percent * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 10,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$completedCount of $total tasks completed',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              Text(
                                '${(total - completedCount)} remaining',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'My Recent Tasks',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  if (myTasks.isEmpty)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Column(
                          children: const [
                            Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No tasks yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Create your first task to get started',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: myTasks.length.clamp(0, 8),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final t = myTasks[i];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          title: Text(
                            t.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            t.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: _statusChip(t.status),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statusCard(
    BuildContext context,
    String label,
    int count,
    Color bg,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color.withAlpha(200),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color.darker(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String? status) {
    final s = (status ?? '').toLowerCase();
    Color bg = Colors.grey.shade200;
    Color text = Colors.black87;
    if (s == 'approved') {
      bg = Colors.green.shade100;
      text = Colors.green.shade800;
    } else if (s == 'pending' || s == 'assigned') {
      bg = Colors.orange.shade100;
      text = Colors.orange.shade800;
    } else if (s == 'rejected') {
      bg = Colors.red.shade100;
      text = Colors.red.shade800;
    } else if (s == 'resubmitted' || s == 'resubmit') {
      bg = Colors.purple.shade100;
      text = Colors.purple.shade800;
    } else if (s == 'completed') {
      bg = Colors.blue.shade100;
      text = Colors.blue.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s.isEmpty ? 'unknown' : s,
        style: TextStyle(color: text, fontWeight: FontWeight.w600),
      ),
    );
  }
}

extension _ColorHelpers on Color {
  Color darker([double amount = .2]) {
    final hsl = HSLColor.fromColor(this);
    final newLightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }
}
