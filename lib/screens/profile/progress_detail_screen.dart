import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_task_service.dart';
import 'package:keitask_management/models/task_model.dart';

/// Progress detail screen: shows approved/pending/rejected/resubmitted counts
/// for the current user, a progress overview and a list of recent tasks.
class ProgressDetailScreen extends StatelessWidget {
  const ProgressDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final tasksService = Provider.of<FirestoreTaskService>(context);
    final currentUserId = auth.appUser?.id ?? auth.firebaseUser?.uid;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress Detail')),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<List<Task>>(
          stream: tasksService.tasksStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final tasks = snap.data ?? [];

            // Filter tasks assigned to current user (support multi-assignees)
            final myTasks = currentUserId == null
                ? <Task>[]
                : tasks
                      .where((t) => t.assignees.contains(currentUserId))
                      .toList();

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
              if (s == 'completed') completedCount++;
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
                        isDark
                            ? Colors.green.withAlpha(50)
                            : Colors.green.shade200,
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _statusCard(
                        context,
                        'Pending',
                        pending,
                        isDark
                            ? Colors.orange.withAlpha(50)
                            : Colors.orange.shade100,
                        Icons.schedule,
                        Colors.orange,
                      ),
                      _statusCard(
                        context,
                        'Rejected',
                        rejected,
                        isDark ? Colors.red.withAlpha(50) : Colors.red.shade100,
                        Icons.cancel,
                        Colors.red,
                      ),
                      _statusCard(
                        context,
                        'Resubmitted',
                        resubmitted,
                        isDark
                            ? Colors.purple.withAlpha(50)
                            : Colors.purple.shade100,
                        Icons.refresh,
                        Colors.purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  Text(
                    'Progress Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    color: Theme.of(context).cardColor,
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
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
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
                  Text(
                    'My Recent Tasks',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (myTasks.isEmpty)
                    Card(
                      color: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                          tileColor: Theme.of(context).cardColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          title: Text(
                            t.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            t.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          trailing: _statusChip(context, t.status),
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
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.black26
                : Colors.white,
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[300]
                        : color.withAlpha(200),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : color.darker(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String? status) {
    final s = (status ?? '').toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg = isDark ? Colors.grey[800]! : Colors.grey.shade200;
    Color text = isDark ? Colors.grey[300]! : Colors.black87;

    if (s == 'approved') {
      bg = isDark ? Colors.green.withAlpha(50) : Colors.green.shade100;
      text = isDark ? Colors.green[200]! : Colors.green.shade800;
    } else if (s == 'pending' || s == 'assigned') {
      bg = isDark ? Colors.orange.withAlpha(50) : Colors.orange.shade100;
      text = isDark ? Colors.orange[200]! : Colors.orange.shade800;
    } else if (s == 'rejected') {
      bg = isDark ? Colors.red.withAlpha(50) : Colors.red.shade100;
      text = isDark ? Colors.red[200]! : Colors.red.shade800;
    } else if (s == 'resubmitted' || s == 'resubmit') {
      bg = isDark ? Colors.purple.withAlpha(50) : Colors.purple.shade100;
      text = isDark ? Colors.purple[200]! : Colors.purple.shade800;
    } else if (s == 'completed') {
      bg = isDark ? Colors.blue.withAlpha(50) : Colors.blue.shade100;
      text = isDark ? Colors.blue[200]! : Colors.blue.shade800;
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
