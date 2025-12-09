import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../services/task_service.dart';
import '../../services/firestore_task_service.dart';
import '../../services/auth_service.dart';
import '../student/task_submission_screen.dart';
import '../../models/grade_model.dart';

class TasksScreen extends StatefulWidget {
  final User? user;
  final bool showBackButton;

  const TasksScreen({super.key, this.user, this.showBackButton = true});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentDisplayedDate = DateTime.now(); // For the header
  bool _showAllTasks = false;
  late ScrollController _dateScrollController;
  // If the screen was opened with a taskId, we store it here to focus once data loads
  String? _pendingTaskId;

  // Cache for user objects to display avatars
  final Map<String, User> _userCache = {};

  bool _isControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isControllerInitialized) {
      _dateScrollController = ScrollController(
        initialScrollOffset:
            (365 * 60.0) - (MediaQuery.of(context).size.width / 2) + 30,
      );
      _dateScrollController.addListener(_onScroll);

      // Center on today after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_dateScrollController.hasClients) {
          _scrollToDate(DateTime.now());
        }
      });
      _isControllerInitialized = true;
    }
  }

  @override
  void dispose() {
    _dateScrollController.removeListener(_onScroll);
    _dateScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_dateScrollController.hasClients) return;
    // Calculate center index
    final double centerOffset =
        _dateScrollController.offset + MediaQuery.of(context).size.width / 2;
    final int index = (centerOffset / 60.0)
        .floor(); // 60 = 50 width + 10 margin

    // index 365 is today (start of list is today - 365)
    final date = DateTime.now().add(Duration(days: index - 365));
    if (date.month != _currentDisplayedDate.month ||
        date.year != _currentDisplayedDate.year) {
      setState(() {
        _currentDisplayedDate = date;
      });
    }
  }

  void _scrollToDate(DateTime date) {
    final diff = date.difference(DateTime.now()).inDays;
    final index = 365 + diff;
    final offset = (index * 60.0) - MediaQuery.of(context).size.width / 2 + 30;
    _dateScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _fetchUsers() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final users = await authService.getAllUsers();
      if (mounted) {
        setState(() {
          for (var user in users) {
            _userCache[user.id] = user;
          }
        });
      }
    } catch (e) {
      // print('Error fetching users for avatars: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreTaskService>(context);
    final effectiveUser = widget.user;

    final monthYear =
        '${_getMonthName(_currentDisplayedDate.month)} ${_currentDisplayedDate.year}';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: widget.showBackButton
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(
          monthYear,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.black87),
            onPressed: () {
              _scrollToDate(DateTime.now());
              setState(() {
                _selectedDate = DateTime.now();
                _currentDisplayedDate = DateTime.now();
              });
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 100), // Spacing for extendBodyBehindAppBar
          // Date Selector (Infinite Scroll)
          Container(
            height: 100, // Increased height to prevent overflow
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              controller: _dateScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: 1000, // Range: Today - 365 to Today + 635
              itemBuilder: (context, index) {
                // index 365 is today
                final dayOffset = index - 365;
                final date = DateTime.now().add(Duration(days: dayOffset));
                final isSelected =
                    date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;

                final isToday =
                    date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;

                final daysOfWeek = [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ];
                final dayName = daysOfWeek[date.weekday - 1];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = DateTime(date.year, date.month, date.day);
                    });
                    _scrollToDate(date);
                  },
                  child: Container(
                    width: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(25), // Capsule shape
                      border: isSelected
                          ? null
                          : Border.all(
                              color: isToday
                                  ? Theme.of(
                                      context,
                                    ).primaryColor.withAlpha(100)
                                  : Theme.of(context).dividerColor,
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withAlpha(100),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white70 : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withAlpha(50)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 16,
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isToday && !isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tasks for ${_selectedDate.day == DateTime.now().day && _selectedDate.month == DateTime.now().month ? "Today" : _formatDateDay(_selectedDate)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showAllTasks = !_showAllTasks),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _showAllTasks
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).dividerColor.withAlpha(50),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _showAllTasks ? 'Show All' : 'Show Daily',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _showAllTasks
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: firestore.tasksStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allTasks = snapshot.data ?? [];

                if (effectiveUser == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No user selected',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final userTasks = allTasks.where((task) {
                  // For professors, show tasks they created OR tasks assigned to them
                  // For students/others, show tasks assigned to them or created by them
                  final matchesUser =
                      task.assignees.contains(effectiveUser.id) ||
                      task.creator == effectiveUser.id;

                  if (_showAllTasks) {
                    return matchesUser;
                  }

                  final matchesDate =
                      task.dueDate.year == _selectedDate.year &&
                      task.dueDate.month == _selectedDate.month &&
                      task.dueDate.day == _selectedDate.day;
                  return matchesUser && matchesDate;
                }).toList();

                if (userTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_available,
                            size: 48,
                            color: Colors.blue[300],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showAllTasks
                              ? 'No tasks found'
                              : 'No tasks for ${_formatDateDay(_selectedDate)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!_showAllTasks)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _showAllTasks = true),
                              child: const Text('View all tasks'),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                // If an initial taskId is provided, attempt to focus the related task
                if (_pendingTaskId != null) {
                  final matching = allTasks
                      .where((t) => t.id == _pendingTaskId)
                      .toList();
                  if (matching.isNotEmpty) {
                    final found = matching.first;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // Show action sheet for the task
                      _showTaskActionsSheet(
                        context,
                        found,
                        Provider.of<TaskService>(context, listen: false),
                        effectiveUser,
                      );
                    });
                  }
                  // Clear pending task id
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _pendingTaskId = null;
                  });
                }

                // Sort: Bookmarked first, then by Due Date (soonest first)
                userTasks.sort((a, b) {
                  final isBookmarkedA =
                      a.bookmarkedBy?.contains(effectiveUser.id) ?? false;
                  final isBookmarkedB =
                      b.bookmarkedBy?.contains(effectiveUser.id) ?? false;

                  if (isBookmarkedA && !isBookmarkedB) return -1;
                  if (!isBookmarkedA && isBookmarkedB) return 1;
                  return a.dueDate.compareTo(b.dueDate);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: userTasks.length,
                  itemBuilder: (context, index) {
                    final task = userTasks[index];
                    return _buildTaskCard(
                      context,
                      task,
                      Provider.of<TaskService>(context),
                      effectiveUser,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTaskActionsSheet(
    BuildContext screenContext,
    Task task,
    TaskService taskService,
    User? effectiveUser,
  ) {
    showModalBottomSheet(
      context: screenContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final statusLower = task.status.toLowerCase();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              if (statusLower == 'rejected')
                ListTile(
                  leading: const Icon(
                    Icons.report_problem,
                    color: Colors.orange,
                  ),
                  title: const Text('View Rejection Reason'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showDialog<void>(
                      context: screenContext,
                      builder: (ctx) {
                        return AlertDialog(
                          title: const Text('Rejection Reason'),
                          content: Text(
                            task.rejectionReason ?? 'No reason provided.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                )
              else ...[
                // Action: Submit Task (Students only)
                if (effectiveUser?.role != 'admin' &&
                    effectiveUser?.role != 'professor')
                  ListTile(
                    leading: const Icon(Icons.upload_file, color: Colors.blue),
                    title: const Text('Submit Task'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        screenContext,
                        MaterialPageRoute(
                          builder: (context) => TaskSubmissionScreen(
                            task: task,
                            user: widget.user!,
                          ),
                        ),
                      );
                    },
                  ),

                // Action: View Submission / Grade
                if (statusLower == 'pending' ||
                    statusLower == 'approved' ||
                    statusLower == 'completed' ||
                    statusLower == 'resubmitted' ||
                    (effectiveUser?.role == 'professor' &&
                        (task.submissions?.isNotEmpty ?? false)))
                  ListTile(
                    leading: const Icon(Icons.visibility, color: Colors.blue),
                    title: Text(
                      effectiveUser?.role == 'professor'
                          ? 'View & Grade'
                          : 'View Submission',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);

                      if (effectiveUser?.role == 'professor') {
                        // Professor View: Show list of submissions
                        final submissions = task.submissions ?? {};
                        if (submissions.isEmpty) {
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            const SnackBar(
                              content: Text('No submissions yet.'),
                            ),
                          );
                          return;
                        }

                        showDialog(
                          context: screenContext,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Submissions'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: submissions.length,
                                itemBuilder: (context, index) {
                                  final studentId = submissions.keys.elementAt(
                                    index,
                                  );
                                  final studentName =
                                      _userCache[studentId]?.name ?? studentId;

                                  final hasGrade =
                                      task.grades != null &&
                                      task.grades!.containsKey(studentId);

                                  return ListTile(
                                    title: Text(studentName),
                                    subtitle: Text(
                                      hasGrade ? 'Graded' : 'Pending Grade',
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                    onTap: () {
                                      Navigator.pop(
                                        dialogContext,
                                      ); // Close LIST dialog
                                      final urls = submissions[studentId]!;
                                      _showGradingDialog(
                                        screenContext,
                                        task,
                                        studentId,
                                        urls,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // Student View: Show my submission
                        if (effectiveUser != null &&
                            task.submissions != null &&
                            task.submissions!.containsKey(effectiveUser.id)) {
                          final myUrls = task.submissions![effectiveUser.id]!;
                          _showGradingDialog(
                            screenContext,
                            task,
                            effectiveUser.id,
                            myUrls,
                          );
                        } else {
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            const SnackBar(
                              content: Text('No submission found for you.'),
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    Task task,
    TaskService taskService,
    User? effectiveUser,
  ) {
    final bool isCompleted = task.status.toLowerCase() == 'completed';
    final bool isApproved =
        task.status.toLowerCase() == 'approved' ||
        (effectiveUser != null &&
            task.grades != null &&
            task.grades!.containsKey(effectiveUser.id));
    final Color iconColor = isCompleted || isApproved
        ? Colors.green
        : Colors.blue;
    final IconData statusIcon = (isCompleted || isApproved)
        ? Icons.check_circle
        : Icons.circle_outlined;

    final now = DateTime.now();
    final isOverdue = !isCompleted && task.dueDate.isBefore(now);
    final daysUntilDue = task.dueDate.difference(now).inDays;

    String getTaskStatus() {
      if (isCompleted) return 'Completed';
      if (isApproved) return 'Approved';
      if (task.status == 'rejected') return 'Rejected';
      if (task.status == 'pending') return 'Pending Review';
      if (task.status == 'assigned') return 'No Submission';
      if (task.status == 'pending_approval') return 'No Submission';
      if (isOverdue) return 'Overdue';
      if (daysUntilDue == 0) return 'Due Today';
      if (daysUntilDue == 1) return 'Due Tomorrow';
      return 'Ongoing';
    }

    final statusText = getTaskStatus();
    final statusColor = isCompleted
        ? Colors.green
        : (isApproved
              ? Colors.green
              : (isOverdue
                    ? Colors.red
                    : (task.status == 'rejected'
                          ? Colors.orange
                          : Colors.blue)));

    final isBookmarked =
        effectiveUser != null &&
        (task.bookmarkedBy?.contains(effectiveUser.id) ?? false);

    return GestureDetector(
      onTap: () =>
          _showTaskActionsSheet(context, task, taskService, effectiveUser),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(
                Theme.of(context).brightness == Brightness.dark ? 50 : 10,
              ),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: isBookmarked ? Colors.blue : Colors.grey,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              if (effectiveUser == null) return;
                              await taskService.toggleBookmark(
                                task.id,
                                effectiveUser.id,
                                !isBookmarked,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Creator Name
                      if ((task.creator?.isNotEmpty ?? false) &&
                          _userCache.containsKey(task.creator))
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: Text(
                            'Assigned by: ${_userCache[task.creator]?.name ?? "Unknown"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Status Badge & Deadline
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDeadline(task.dueDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: isOverdue ? Colors.red : Colors.grey[600],
                              fontWeight: isOverdue
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Grade Display
            if (effectiveUser != null &&
                task.grades != null &&
                task.grades!.containsKey(effectiveUser.id)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Grade: ${task.grades![effectiveUser.id]!.score.toStringAsFixed(1)} / 100',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                    if (task.grades![effectiveUser.id]!.comment != null &&
                        task
                            .grades![effectiveUser.id]!
                            .comment!
                            .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Comment: ${task.grades![effectiveUser.id]!.comment}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[900],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            if (task.assignees.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: task.assignees.length > 4
                          ? 5
                          : task.assignees.length,
                      itemBuilder: (context, index) {
                        if (index == 4) {
                          return CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.grey[200],
                            child: Text(
                              '+${task.assignees.length - 4}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        final assigneeId = task.assignees[index];
                        final isUserCompleted =
                            task.completionStatus != null &&
                            task.completionStatus!.containsKey(assigneeId);
                        final assigneeUser = _userCache[assigneeId];

                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blue[50],
                                backgroundImage:
                                    (assigneeUser?.profileImage?.isNotEmpty ??
                                        false)
                                    ? NetworkImage(assigneeUser!.profileImage!)
                                    : null,
                                child:
                                    (assigneeUser?.profileImage == null ||
                                        assigneeUser!.profileImage!.isEmpty)
                                    ? Text(
                                        _getUserInitials(assigneeId),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              if (isUserCompleted)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.fromBorderSide(
                                        BorderSide(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked ? Colors.blue : Colors.grey[400],
                      size: 20,
                    ),
                    onPressed: effectiveUser == null
                        ? null
                        : () async {
                            final firestore = Provider.of<FirestoreTaskService>(
                              context,
                              listen: false,
                            );
                            try {
                              await firestore.toggleBookmark(
                                task.id,
                                effectiveUser.id,
                                !isBookmarked,
                              );
                            } catch (_) {}
                          },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getUserInitials(String userId) {
    final user = _userCache[userId];
    if (user != null && user.name.isNotEmpty) {
      return user.name[0].toUpperCase();
    }
    return '?';
  }

  String _formatDeadline(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isTomorrow =
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day + 1;

    String timeStr =
        '${date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour)}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';

    if (isToday) {
      return 'Today at $timeStr';
    } else if (isTomorrow) {
      return 'Tomorrow at $timeStr';
    } else if (difference.inDays < 7 && difference.inDays > 0) {
      // Show day name
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[date.weekday - 1]} at $timeStr';
    } else {
      return '${date.day}/${date.month}/${date.year} at $timeStr';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatDateDay(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month).substring(0, 3)}';
  }

  void _showGradingDialog(
    BuildContext context,
    Task task,
    String studentId,
    List<String> submissionUrls,
  ) {
    final scoreController = TextEditingController();
    final maxScoreController = TextEditingController();
    final commentController = TextEditingController();

    // Pre-fill if already graded
    if (task.grades != null && task.grades!.containsKey(studentId)) {
      final existing = task.grades![studentId]!;
      scoreController.text = existing.score.toString();
      maxScoreController.text = existing.maxScore.toString();
      commentController.text = existing.comment ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grade Submission'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Submission Links & Previews
              const Text(
                'Documents:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...submissionUrls.map((url) {
                final isImage = _isImage(url);
                final fileName = url.split('/').last.split('?').first;
                final shortName = fileName.length > 30
                    ? '${fileName.substring(0, 30)}...'
                    : fileName;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isImage ? Icons.image : Icons.insert_drive_file,
                            color: isImage ? Colors.purple : Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              shortName,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Download/Open Button
                          IconButton(
                            icon: const Icon(Icons.download_rounded, size: 20),
                            color: Colors.grey[700],
                            tooltip: 'Download / Open',
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              try {
                                final downloadUrl = _getDownloadUrl(url);
                                final uri = Uri.parse(downloadUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              } catch (_) {}
                            },
                          ),
                        ],
                      ),
                      if (isImage) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: EdgeInsets.zero,
                                child: Stack(
                                  children: [
                                    InteractiveViewer(
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.contain,
                                        height: double.infinity,
                                        width: double.infinity,
                                        loadingBuilder: (ctx, child, progress) {
                                          if (progress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  progress.expectedTotalBytes !=
                                                      null
                                                  ? progress.cumulativeBytesLoaded /
                                                        progress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      top: 40,
                                      right: 20,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, error, stack) => Container(
                                height: 150,
                                color: Colors.grey[200],
                                alignment: Alignment.center,
                                child: const Text('Image Error'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              TextField(
                controller: scoreController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Score'),
              ),
              TextField(
                controller: maxScoreController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max Score'),
              ),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Comments/Feedback',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final score = double.tryParse(scoreController.text);
              final maxScore = double.tryParse(maxScoreController.text);

              if (score == null || maxScore == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid numbers')),
                );
                return;
              }

              final grade = Grade(
                score: score,
                maxScore: maxScore,
                comment: commentController.text,
                gradedBy: widget.user!.id,
                gradedAt: DateTime.now(),
              );

              final firestore = Provider.of<FirestoreTaskService>(
                context,
                listen: false,
              );
              await firestore.gradeTask(task.id, studentId, grade);

              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Grade saved!')));
            },
            child: const Text('Save Grade'),
          ),
        ],
      ),
    );
  }

  String _getDownloadUrl(String url) {
    if (url.contains('cloudinary.com') && url.contains('/upload/')) {
      return url.replaceFirst('/upload/', '/upload/fl_attachment/');
    }
    return url;
  }

  bool _isImage(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }
}
