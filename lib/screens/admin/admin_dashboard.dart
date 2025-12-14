import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_notification_service.dart';
import '../../services/firestore_task_service.dart';
import '../../models/user_model.dart'
    as app_models; // Alias to avoid conflict if needed, though Task is in separate file usually.
// Actually Task is in user_model.dart?? No, I saw it there. Yes, Task class is in user_model.dart.
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'admin_reports_screen.dart'; // Reports Inbox

class AdminDashboard extends StatefulWidget {
  final User user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  void _showBroadcastDialog(BuildContext context) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    // Check if provider exists to prevent crash (it always crash when i use it)
    FirestoreNotificationService? notificationService;
    try {
      notificationService = Provider.of<FirestoreNotificationService>(
        context,
        listen: false,
      );
    } catch (e) {
      debugPrint('Notification Service Provider Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification service unavailable (Check logs)'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Broadcast'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., System Maintenance',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bodyController,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'e.g., The system will be down at midnight.',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final body = bodyController.text.trim();
              if (title.isNotEmpty && body.isNotEmpty) {
                notificationService?.createBroadcastNotification(title, body);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Broadcast sent successfully')),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Stream users to calculate stats
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<User>>(
        stream: authService.usersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data ?? [];

          final totalUsers = users.length;
          final totalStudents = users
              .where((u) => u.role == 'student' || u.role == 'user')
              .length;
          final totalProfessors = users
              .where((u) => u.role == 'professor' && u.isApproved)
              .length;
          final pendingApprovals = users
              .where((u) => u.role == 'professor' && !u.isApproved)
              .length;

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Blue Header Section with Gradient
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1565C0), // Blue 800
                          const Color(0xFF1E88E5), // Blue 600
                          const Color(0xFF42A5F5), // Blue 400
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withAlpha(50),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${widget.user.name}!',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(50),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'System Administrator',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.inbox_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminReportsScreen(),
                                    ),
                                  );
                                },
                                tooltip: 'Reports Inbox',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.blue[100],
                                backgroundImage:
                                    (widget.user.profileImage != null &&
                                        widget.user.profileImage!.isNotEmpty)
                                    ? NetworkImage(widget.user.profileImage!)
                                          as ImageProvider
                                    : null,
                                child:
                                    (widget.user.profileImage == null ||
                                        widget.user.profileImage!.isEmpty)
                                    ? Text(
                                        widget.user.name.isNotEmpty
                                            ? widget.user.name[0].toUpperCase()
                                            : 'A',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[800],
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Content Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Cards Grid (2x2)
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.25,
                          children: [
                            _buildStatCard(
                              'Total Users',
                              '$totalUsers',
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.blue.withAlpha(50)
                                  : Colors.blue[50]!,
                              Colors.blue,
                              Icons.people,
                            ),
                            _buildStatCard(
                              'Total Students',
                              '$totalStudents',
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.green.withAlpha(50)
                                  : const Color(0xFFE8F5E9),
                              Colors.green,
                              Icons.school,
                            ),
                            _buildStatCard(
                              'Active Professors',
                              '$totalProfessors',
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.purple.withAlpha(50)
                                  : const Color(0xFFF3E5F5),
                              Colors.purple,
                              Icons.person_outline,
                            ),
                            _buildStatCard(
                              'Pending Approvals',
                              '$pendingApprovals',
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.orange.withAlpha(50)
                                  : const Color(0xFFFFF3E0),
                              Colors.orange,
                              Icons.pending_actions,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Analytics Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analytics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // User Growth Chart
                        Container(
                          height: 240,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Growth',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Expanded(child: _buildUserGrowthChart(users)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // User Activity Chart (New)
                        Container(
                          height: 240,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Activities (Online)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Expanded(child: _buildUserActivityChart(users)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Task Status Chart
                        StreamBuilder<List<app_models.Task>>(
                          stream: Provider.of<FirestoreTaskService>(
                            context,
                            listen: false,
                          ).tasksStream(),
                          builder: (context, taskSnapshot) {
                            if (!taskSnapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final tasks = taskSnapshot.data!;
                            return Container(
                              height: 240,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(20),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Task Distribution',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Expanded(child: _buildTaskStatusChart(tasks)),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 80), // Bottom padding
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'broadcast',
            onPressed: () => _showBroadcastDialog(context),
            backgroundColor: Colors.blue,
            child: const Icon(Icons.campaign, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    Color backgroundColor,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [backgroundColor, backgroundColor.withAlpha(200)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white.withAlpha(50), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(150),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                count,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color.withAlpha(230),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrowthChart(List<User> users) {
    if (users.isEmpty) return const Center(child: Text('No user data'));

    // Fallback: If creation date is missing, treat them as "joined today"
    // so we can at least show the total count in the chart.
    final List<User> processedUsers = users.map((u) {
      if (u.createdAt == null) {
        // Return a modified copy (conceptually) or just handle logic here
        // We can't modify the User object easily if it's final, but we can treat the date as now.
        return User(
          id: u.id,
          email: u.email,
          name: u.name,
          role: u.role,
          profileImage: u.profileImage,
          isApproved: u.isApproved,
          createdAt: DateTime.now(), // Fallback
          lastActive: u.lastActive,
          phoneNumber: u.phoneNumber,
          address: u.address,
          isBanned: u.isBanned,
          notificationsEnabled: u.notificationsEnabled,
        );
      }
      return u;
    }).toList();

    processedUsers.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

    final Map<int, int> growthMap = {};
    int count = 0; // Start counting from the beginning of our processed list

    for (var user in processedUsers) {
      count++;
      final date = user.createdAt!;
      final dayKey = DateTime(
        date.year,
        date.month,
        date.day,
      ).millisecondsSinceEpoch;
      growthMap[dayKey] = count;
    }

    // Handle single data point case by adding a fake previous point
    if (growthMap.length == 1) {
      final singleKey = growthMap.keys.first;
      final yesterday = DateTime.fromMillisecondsSinceEpoch(
        singleKey,
      ).subtract(const Duration(days: 1));
      growthMap[yesterday.millisecondsSinceEpoch] = 0; // Start from 0 yesterday
    }

    final sortedKeys = growthMap.keys.toList()..sort();

    final spots = sortedKeys.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), growthMap[e.value]!.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedKeys.length) {
                  final totalPoints = sortedKeys.length;
                  // Show ~5 labels
                  final interval = (totalPoints / 5).ceil();

                  if (index % interval == 0 || index == totalPoints - 1) {
                    final dateMs = sortedKeys[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(dateMs);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('MM/dd').format(date),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }
                }
                return const SizedBox();
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (sortedKeys.length - 1).toDouble(),
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withAlpha(40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatusChart(List<app_models.Task> tasks) {
    if (tasks.isEmpty) return const Center(child: Text('No tasks created yet'));

    final completed = tasks
        .where(
          (t) =>
              t.status.toLowerCase() == 'completed' ||
              t.status.toLowerCase() == 'approved',
        )
        .length;
    final pending = tasks
        .where(
          (t) =>
              t.status.toLowerCase() == 'pending' ||
              t.status.toLowerCase() == 'submitted' ||
              t.status.toLowerCase() == 'assigned',
        )
        .length;
    final rejected = tasks
        .where((t) => t.status.toLowerCase() == 'rejected')
        .length;

    if (completed == 0 && pending == 0 && rejected == 0) {
      return const Center(child: Text('No active task data'));
    }

    final total = tasks.length;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  if (completed > 0)
                    PieChartSectionData(
                      color: Colors.green,
                      value: completed.toDouble(),
                      title:
                          '${((completed / total) * 100).toStringAsFixed(0)}%',
                      radius: 40,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (pending > 0)
                    PieChartSectionData(
                      color: Colors.orange,
                      value: pending.toDouble(),
                      title: '${((pending / total) * 100).toStringAsFixed(0)}%',
                      radius: 40,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (rejected > 0)
                    PieChartSectionData(
                      color: Colors.red,
                      value: rejected.toDouble(),
                      title:
                          '${((rejected / total) * 100).toStringAsFixed(0)}%',
                      radius: 40,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegendItem('Completed', Colors.green, completed),
            const SizedBox(height: 8),
            _buildLegendItem('Pending', Colors.orange, pending),
            const SizedBox(height: 8),
            _buildLegendItem('Rejected', Colors.red, rejected),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String title, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$title: $count', style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildUserActivityChart(List<User> users) {
    // 1. Filter users with lastActive
    final activeUsers = users.where((u) => u.lastActive != null).toList();
    if (activeUsers.isEmpty) {
      return const Center(child: Text('No activity data yet'));
    }

    // 2. Group by "Time Ago" categories
    int today = 0;
    int yesterday = 0;
    int thisWeek = 0;
    int older = 0;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 7));

    for (var user in activeUsers) {
      final lastActive = user.lastActive!;
      if (lastActive.isAfter(todayStart)) {
        today++;
      } else if (lastActive.isAfter(yesterdayStart)) {
        yesterday++;
      } else if (lastActive.isAfter(weekStart)) {
        thisWeek++;
      } else {
        older++;
      }
    }

    // 3. Prepare Bar Chart Data
    // 0: Today, 1: Yesterday, 2: This Week, 3: Older
    final barGroups = [
      _makeBarGroup(0, today.toDouble(), Colors.blue),
      _makeBarGroup(1, yesterday.toDouble(), Colors.lightBlue),
      _makeBarGroup(2, thisWeek.toDouble(), Colors.orange),
      _makeBarGroup(3, older.toDouble(), Colors.grey),
    ];

    // Find max Y for consistent scaling
    double maxY = 0;
    for (var g in barGroups) {
      if (g.barRods.first.toY > maxY) maxY = g.barRods.first.toY;
    }
    maxY = (maxY * 1.2).ceilToDouble(); // Add headroom
    if (maxY == 0) maxY = 5;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                );
                String text;
                switch (value.toInt()) {
                  case 0:
                    text = 'Today';
                    break;
                  case 1:
                    text = 'Yest.';
                    break;
                  case 2:
                    text = 'Week';
                    break;
                  case 3:
                    text = 'Older';
                    break;
                  default:
                    text = '';
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(text, style: style),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxY > 10 ? 5 : 1,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox(); // Integers only
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 10 ? 5 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.withAlpha(50), strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 16,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 0, // No full background needed
            color: Colors.grey.withAlpha(30),
          ),
        ),
      ],
    );
  }
}
