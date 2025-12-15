import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/firestore_task_service.dart';
import 'package:keitask_management/models/task_model.dart';

class TaskStatisticsScreen extends StatelessWidget {
  final bool showBackButton;
  const TaskStatisticsScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreTaskService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Analytics'),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: StreamBuilder<List<Task>>(
        stream: firestoreService.tasksStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No task data available'));
          }

          final tasks = snapshot.data!;
          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

          // Calculate daily completions for the current week
          final Map<int, int> dailyCompletions = {
            1: 0,
            2: 0,
            3: 0,
            4: 0,
            5: 0,
            6: 0,
            7: 0,
          };

          for (var task in tasks) {
            if (task.status == 'completed' && task.completedAt != null) {
              if (task.completedAt!.isAfter(startOfWeek)) {
                dailyCompletions[task.completedAt!.weekday] =
                    (dailyCompletions[task.completedAt!.weekday] ?? 0) + 1;
              }
            }
            // Also check per-user completion status
            if (task.completionStatus != null) {
              task.completionStatus!.forEach((userId, completedAt) {
                if (completedAt.isAfter(startOfWeek)) {
                  dailyCompletions[completedAt.weekday] =
                      (dailyCompletions[completedAt.weekday] ?? 0) + 1;
                }
              });
            }
          }

          final maxCompletions = dailyCompletions.values.reduce(
            (a, b) => a > b ? a : b,
          );
          final maxY = (maxCompletions + 5).toDouble();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly Task Completions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: 1.5,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.blueGrey,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              rod.toY.round().toString(),
                              const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              if (value.toInt() >= 0 &&
                                  value.toInt() < days.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    days[value.toInt()],
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value % 1 == 0) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(7, (index) {
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: dailyCompletions[index + 1]!.toDouble(),
                              color: Colors.blue,
                              width: 16,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSummaryCard(tasks),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(List<Task> tasks) {
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.status == 'completed').length;
    final completionRate = totalTasks > 0
        ? (completedTasks / totalTasks * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Tasks', '$totalTasks'),
          _buildStatItem('Completed', '$completedTasks'),
          _buildStatItem('Rate', '$completionRate%'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
        ),
      ],
    );
  }
}
