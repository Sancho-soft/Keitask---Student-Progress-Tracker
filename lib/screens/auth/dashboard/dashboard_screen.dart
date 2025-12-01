import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_task_service.dart';
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
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsSupported =
      false; // Track if plugin should be used on this platform

  // Track known task IDs to detect new ones
  Set<String> _knownTaskIds = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    // Only try to init the plugin when the platform appears to support it.
    _notificationsSupported = !_isWebAndUnsupported();
    if (_notificationsSupported) {
      _initNotifications();
    }
    _listenForNewTasks();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    try {
      await _notificationsPlugin.initialize(settings);
    } catch (e) {
      // If plugin is not registered on this platform (e.g., web or missing
      // registration), avoid crashing the app and disable notifications.
      debugPrint('Failed to initialize local notifications: $e');
      _notificationsSupported = false;
    }
  }

  void _listenForNewTasks() {
    final firestore = Provider.of<FirestoreTaskService>(context, listen: false);
    firestore.tasksStream().listen((tasks) {
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

      for (var task in myTasks) {
        if (!_knownTaskIds.contains(task.id)) {
          _knownTaskIds.add(task.id);
          _showNotification(task);
        }
      }
    });
  }

  Future<void> _showNotification(Task task) async {
    if (!_notificationsSupported) return;
    const androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Task Assignments',
      channelDescription: 'Notifications for new task assignments',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      task.hashCode,
      'New Task Assigned',
      'You have been assigned: ${task.title}',
      details,
    );
  }

  // Helper to detect unsupported scenarios (e.g., web builds)
  bool _isWebAndUnsupported() {
    if (kIsWeb) return true;
    // defaultTargetPlatform will return a platform enum for a given build target
    // so we can detect desktop / mobile. The plugin supports Android/iOS, and
    // some versions support desktop. We'll conservatively assume desktop support
    // may vary and still check for Android/iOS primarily.
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
      return false;
    }
    // For desktop (macOS/windows/linux), allow but wrap in try/catch since
    // plugin availability could vary.
    return false;
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
