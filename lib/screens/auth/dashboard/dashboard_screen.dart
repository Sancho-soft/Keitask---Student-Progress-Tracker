// keitask_management/lib/screens/auth/dashboard/dashboard_screen.dart (MODIFIED FOR TAB SWITCHING)

import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import 'package:keitask_management/widgets/circular_nav_bar.dart';
import '../tasks/tasks_screen.dart';
import '../profile/profile_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import 'admin_dashboard.dart';
import 'user_dashboard.dart';
import '../tasks/admin_tasks_approval_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  // FIX: This function is called by the ProfileScreen's back button
  void _backToHome() {
    setState(() => _currentIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    final isUserAdmin = widget.user.role == 'admin';

    // Define the list of screens based on the user's role
    final List<Widget> userScreens = [
      UserDashboard(user: widget.user),
      TasksScreen(user: widget.user),
      const LeaderboardScreen(),
      // FIX: Pass the callback to the ProfileScreen
      ProfileScreen(user: widget.user, onBackToHome: _backToHome),
    ];

    final List<Widget> adminScreens = [
      AdminDashboard(user: widget.user),
      AdminTasksApprovalScreen(user: widget.user),
      const LeaderboardScreen(),
      // FIX: Pass the callback to the ProfileScreen
      ProfileScreen(user: widget.user, onBackToHome: _backToHome),
    ];

    final screens = isUserAdmin ? adminScreens : userScreens;

    return Scaffold(
      // Ensure scaffold reserves space for bottom nav so body isn't overlapped
      extendBody: false,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 0.0),
        child: CircularNavBar(
          items: [
            const CircularNavBarItem(icon: Icons.home, label: 'Home'),
            CircularNavBarItem(
              icon: Icons.task,
              label: isUserAdmin ? 'Task Approval' : 'Tasks',
            ),
            const CircularNavBarItem(
              icon: Icons.leaderboard,
              label: 'Leaderboard',
            ),
            const CircularNavBarItem(icon: Icons.person, label: 'Profile'),
          ],
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
        ),
      ),
    );
  }
}
