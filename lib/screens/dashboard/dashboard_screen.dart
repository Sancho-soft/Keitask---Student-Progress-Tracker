import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notification_service.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

import '../../models/user_model.dart';
import '../../services/firestore_task_service.dart';
import 'package:keitask_management/widgets/circular_nav_bar.dart';
import '../tasks/tasks_screen.dart';
import '../profile/profile_screen.dart';
import 'admin_dashboard.dart';
import 'user_dashboard.dart';
import '../tasks/admin_tasks_approval_screen.dart';
import '../admin/users_screen.dart';
import '../admin/task_statistics_screen.dart';
import '../leaderboard/leaderboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  // Use NotificationService for cross-platform safety

  // Track known task IDs to detect new ones
  Set<String> _knownTaskIds = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    // No-op here; NotificationService should be initialized from main.dart. If it wasn't,
    // NotificationService.init() ran at startup and it's safe to call showTaskNotification.
    _listenForNewTasks();
  }

  // Initialization for NotificationService occurs in main.dart (or can be handled lazily in the service itself)

  void _listenForNewTasks() {
    final firestore = Provider.of<FirestoreTaskService>(context, listen: false);
    firestore.tasksStream().listen(
      (tasks) {
        if (!mounted) return;

        // Filter tasks assigned to this user
        final myTasks = tasks
            .where((t) => t.assignees.contains(widget.user.id))
            .toList();

        if (_isFirstLoad) {
          _knownTaskIds = myTasks.map((t) => t.id).toSet();
          _isFirstLoad = false;
          return;
        }

        final authService = Provider.of<AuthService>(context, listen: false);
        final userPrefs = authService.appUser?.notificationsEnabled ?? true;
        for (var task in myTasks) {
          if (!_knownTaskIds.contains(task.id)) {
            _knownTaskIds.add(task.id);
            if (userPrefs) NotificationService.showTaskNotification(task);
          }
        }
      },
      onError: (e) {
        debugPrint('Error in tasks stream: $e');
      },
    );

    // Listen for admin notifications
    FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: widget.user.id)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data != null) {
                  final title = data['title'] as String? ?? 'New Notification';
                  final body = data['body'] as String? ?? '';

                  // Mark as read immediately to avoid re-showing
                  change.doc.reference.update({'read': true});

                  // Show local notification
                  NotificationService.showGeneralNotification(
                    id: change.doc.hashCode,
                    title: title,
                    body: body,
                  );
                }
              }
            }
          },
          onError: (e) {
            debugPrint('Error in notifications stream: $e');
          },
        );
  }

  // Removed the local plugin wrapper in favor of NotificationService

  // Helper to detect unsupported scenarios (e.g., web builds)
  // NotificationService handles platform compatibility internally.

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
        const LeaderboardScreen(),
        ProfileScreen(user: widget.user, onBackToHome: _backToHome),
      ];
      navItems = [
        const CircularNavBarItem(icon: Icons.home, label: 'Home'),
        const CircularNavBarItem(icon: Icons.check_circle, label: 'Approvals'),
        const CircularNavBarItem(
          icon: Icons.manage_accounts,
          label: 'Manage Users',
        ),
        const CircularNavBarItem(icon: Icons.leaderboard, label: 'Rank'),
        const CircularNavBarItem(icon: Icons.person, label: 'Profile'),
      ];
    } else if (isProfessor) {
      screens = [
        UserDashboard(
          user: widget.user,
          onSeeAllTasks: () => _onTabSelected(1), // Switch to Tasks tab
        ),
        AdminTasksApprovalScreen(
          user: widget.user,
        ), // Professors use this to approve/reject
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
        const LeaderboardScreen(),
        ProfileScreen(user: widget.user, onBackToHome: _backToHome),
      ];
      navItems = [
        const CircularNavBarItem(icon: Icons.home, label: 'Home'),
        const CircularNavBarItem(icon: Icons.task, label: 'Tasks'),
        const CircularNavBarItem(icon: Icons.leaderboard, label: 'Rank'),
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
      // Add a debug FAB for quick notification testing in debug mode
      floatingActionButton: null,
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
