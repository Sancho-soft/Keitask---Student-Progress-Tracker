import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import 'package:keitask_management/widgets/circular_nav_bar.dart';
import '../tasks/tasks_screen.dart';
import '../profile/profile_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import 'admin_dashboard.dart';
import 'user_dashboard.dart';
import '../tasks/admin_tasks_approval_screen.dart';
import '../../admin/users_screen.dart';
import '../../admin/task_statistics_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    final role = widget.user.role.toLowerCase();
    if (role == 'professor' && index == 2) {
      // "New Task" action - Navigate to CreateTaskScreen
      Navigator.pushNamed(context, '/create-task', arguments: widget.user);
      return; // Do not update _currentIndex
    }

    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _backToHome() {
    setState(() => _currentIndex = 0);
    _pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user.role.toLowerCase();
    final isAdmin = role == 'admin';
    final isProfessor = role == 'professor';

    List<Widget> screens;
    List<CircularNavBarItem> navItems;

    if (isAdmin) {
      screens = [
        AdminDashboard(user: widget.user),
        AdminTasksApprovalScreen(user: widget.user),
        const UsersScreen(showBackButton: false),
        const LeaderboardScreen(showBackButton: false),
        ProfileScreen(user: widget.user, onBackToHome: _backToHome),
      ];
      navItems = [
        const CircularNavBarItem(icon: Icons.home, label: 'Home'),
        const CircularNavBarItem(icon: Icons.check_circle, label: 'Approvals'),
        const CircularNavBarItem(
          icon: Icons.manage_accounts,
          label: 'Manage Users',
        ),
        const CircularNavBarItem(icon: Icons.leaderboard, label: 'Leaderboard'),
        const CircularNavBarItem(icon: Icons.person, label: 'Profile'),
      ];
    } else if (isProfessor) {
      screens = [
        UserDashboard(user: widget.user),
        TasksScreen(user: widget.user, showBackButton: false),
        const SizedBox(), // Placeholder for "New Task" (handled in _onTabSelected)
        const TaskStatisticsScreen(showBackButton: false),
        ProfileScreen(user: widget.user, onBackToHome: _backToHome),
      ];
      navItems = [
        const CircularNavBarItem(icon: Icons.home, label: 'Home'),
        const CircularNavBarItem(icon: Icons.task, label: 'Tasks'),
        const CircularNavBarItem(icon: Icons.add_circle, label: 'New Task'),
        const CircularNavBarItem(icon: Icons.analytics, label: 'Analytics'),
        const CircularNavBarItem(icon: Icons.person, label: 'Profile'),
      ];
    } else {
      // Student
      screens = [
        UserDashboard(user: widget.user),
        TasksScreen(user: widget.user, showBackButton: false),
        const LeaderboardScreen(showBackButton: false),
        ProfileScreen(user: widget.user, onBackToHome: _backToHome),
      ];
      navItems = [
        const CircularNavBarItem(icon: Icons.home, label: 'Home'),
        const CircularNavBarItem(icon: Icons.task, label: 'Tasks'),
        const CircularNavBarItem(icon: Icons.leaderboard, label: 'Leaderboard'),
        const CircularNavBarItem(icon: Icons.person, label: 'Profile'),
      ];
    }

    // Keep current index within bounds
    if (_currentIndex >= screens.length) {
      _currentIndex = screens.length - 1;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    }

    return Scaffold(
      extendBody: false,
      body: PageView(
        controller: _pageController,
        physics:
            const NeverScrollableScrollPhysics(), // Disable swipe to avoid accidental "New Task" selection
        onPageChanged: (int idx) => setState(() => _currentIndex = idx),
        children: screens,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 0.0),
        child: CircularNavBar(
          items: navItems,
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
        ),
      ),
    );
  }
}
