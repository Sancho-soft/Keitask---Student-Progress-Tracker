import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../professor/create_task_screen.dart';
import '../../widgets/flash_message.dart';
import 'package:intl/intl.dart';

class UsersScreen extends StatefulWidget {
  final bool showBackButton;
  const UsersScreen({super.key, this.showBackButton = true});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  // Filter states
  String _roleFilter = 'all'; // 'all', 'professor', 'student'
  bool _showBanned = false; // Toggle for banned users
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final Set<String> _selectedUserIds = {};
  bool _isSelectionMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
        if (_selectedUserIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedUserIds.add(userId);
        _isSelectionMode = true;
      }
    });
  }

  void _assignTaskToSelected(BuildContext context, User currentUser) {
    if (_selectedUserIds.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTaskScreen(
          user: currentUser,
          adminCreate: true, // Professors/Admins assigning tasks
          initialAssignees: _selectedUserIds.toList(),
        ),
      ),
    ).then((_) {
      // Clear selection after returning
      setState(() {
        _selectedUserIds.clear();
        _isSelectionMode = false;
      });
    });
  }

  void _showUserDetails(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage:
                  (user.profileImage != null && user.profileImage!.isNotEmpty)
                  ? NetworkImage(user.profileImage!)
                  : null,
              child: (user.profileImage == null || user.profileImage!.isEmpty)
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(user.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.email, 'Email', user.email),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.phone, 'Phone', user.phoneNumber ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.location_on,
              'Address',
              user.address ?? 'N/A',
            ),
            const SizedBox(height: 8),

            _buildDetailRow(
              Icons.calendar_today,
              'Joined',
              user.createdAt != null
                  ? DateFormat('MMM d, yyyy').format(user.createdAt!)
                  : 'N/A',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.badge, 'Role', user.role.toUpperCase()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.appUser;
    final isProfessor = currentUser?.role == 'professor';
    final isAdmin = currentUser?.role == 'admin';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Force filter for professors if not already set (Professors can only see students usually)
    // But allowing professors to see other users depends on requirements.
    // Assuming professors manage students.
    if (isProfessor && _roleFilter != 'student') {
      _roleFilter = 'student';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedUserIds.length} Selected'
              : (isProfessor ? 'My Students' : 'Manage Users'),
          style: TextStyle(
            color: _isSelectionMode
                ? null
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton || _isSelectionMode
            ? IconButton(
                icon: Icon(_isSelectionMode ? Icons.close : Icons.arrow_back),
                onPressed: () {
                  if (_isSelectionMode) {
                    setState(() {
                      _selectedUserIds.clear();
                      _isSelectionMode = false;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!isProfessor) // Admin Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          'All',
                          _roleFilter == 'all' && !_showBanned,
                          () {
                            setState(() {
                              _roleFilter = 'all';
                              _showBanned = false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Students',
                          _roleFilter == 'student' && !_showBanned,
                          () {
                            setState(() {
                              _roleFilter = 'student';
                              _showBanned = false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Professors',
                          _roleFilter == 'professor' && !_showBanned,
                          () {
                            setState(() {
                              _roleFilter = 'professor';
                              _showBanned = false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Pending',
                          _roleFilter == 'pending' && !_showBanned,
                          () {
                            setState(() {
                              _roleFilter = 'pending'; // New filter logic
                              _showBanned = false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Banned Users'),
                          selected: _showBanned,
                          onSelected: (val) {
                            setState(() {
                              _showBanned = val;
                              if (val) {
                                _roleFilter =
                                    'all'; // Reset role filter when showing banned
                              }
                            });
                          },
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          selectedColor: isDark
                              ? Colors.red.withAlpha(50)
                              : Colors.red[100],
                          labelStyle: TextStyle(
                            color: _showBanned
                                ? Colors.red
                                : (isDark ? Colors.grey[300] : Colors.black87),
                            fontWeight: _showBanned
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          checkmarkColor: Colors.red,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<User>>(
              stream: authService.usersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final users = snapshot.data ?? [];

                final filteredUsers = users.where((user) {
                  // Exclude self
                  if (user.id == currentUser?.id) return false;

                  // 1. Search Filter
                  if (_searchQuery.isNotEmpty &&
                      !user.name.toLowerCase().contains(_searchQuery)) {
                    return false;
                  }

                  // 2. Banned Filter (Priority)
                  if (_showBanned) {
                    return user.isBanned;
                  }

                  // Hide Banned users from normal lists (unless Banned filter is ON)
                  if (user.isBanned) return false;

                  // 3. Role Filter
                  if (_roleFilter == 'student') {
                    if (user.role != 'student' && user.role != 'user') {
                      return false;
                    }
                  } else if (_roleFilter == 'professor') {
                    if (user.role != 'professor') return false;
                  } else if (_roleFilter == 'pending') {
                    if (user.role == 'professor' && !user.isApproved) {
                      return true;
                    }
                    return false;
                  }

                  // 4. Professor Approval Logic
                  // We SHOULD show unapproved professors so admins can approve them
                  // Unless filtered out by role

                  return true;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No users found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final isUserProfessor = user.role == 'professor';
                    final isSelected = _selectedUserIds.contains(user.id);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected
                            ? const BorderSide(color: Colors.blue, width: 2)
                            : BorderSide.none,
                      ),
                      color: isSelected
                          ? Colors.blue.withAlpha(50)
                          : Theme.of(context).cardColor,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(user.id);
                              } else if (isAdmin) {
                                // Show Details Dialog
                                _showUserDetails(context, user);
                              } else if (isProfessor) {
                                // Maybe show details for students too?
                                _showUserDetails(context, user);
                              }
                            },
                            onLongPress: () {
                              if (isProfessor || isAdmin) {
                                _toggleSelection(user.id);
                              }
                            },
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage:
                                      user.profileImage != null &&
                                          user.profileImage!.isNotEmpty
                                      ? NetworkImage(user.profileImage!)
                                      : null,
                                  child:
                                      (user.profileImage == null ||
                                          user.profileImage!.isEmpty)
                                      ? Text(
                                          user.name.isNotEmpty
                                              ? user.name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        )
                                      : null,
                                ),
                                if (isSelected)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                if (user.isBanned)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.block,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              user.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: user.isBanned
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: user.isBanned ? Colors.grey : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.email),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isUserProfessor
                                            ? (isDark
                                                  ? Colors.purple.withAlpha(50)
                                                  : Colors.purple[100])
                                            : (isDark
                                                  ? Colors.blue.withAlpha(50)
                                                  : Colors.blue[100]),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        (user.role == 'user' ||
                                                user.role == 'student')
                                            ? 'STUDENT'
                                            : user.role.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isUserProfessor
                                              ? (isDark
                                                    ? Colors.purple[200]
                                                    : Colors.purple[800])
                                              : (isDark
                                                    ? Colors.blue[200]
                                                    : Colors.blue[800]),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (user.isBanned) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.red.withAlpha(50)
                                              : Colors.red[100],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          'BANNED',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? Colors.red[200]
                                                : Colors.red[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: _isSelectionMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (val) =>
                                        _toggleSelection(user.id),
                                  )
                                : null,
                          ),
                          // Admin Actions Row
                          if (isAdmin && !_isSelectionMode)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 8,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Ban/Unban Button (Now available for Professors too)
                                  TextButton.icon(
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(
                                            user.isBanned
                                                ? 'Unban User'
                                                : 'Ban User',
                                          ),
                                          content: Text(
                                            user.isBanned
                                                ? 'Are you sure you want to unban ${user.name}?'
                                                : 'Are you sure you want to ban ${user.name}? They will be signed out immediately.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: Text(
                                                user.isBanned ? 'Unban' : 'Ban',
                                                style: TextStyle(
                                                  color: user.isBanned
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        try {
                                          await authService.banUser(
                                            user.id,
                                            !user.isBanned,
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                user.isBanned
                                                    ? 'User unbanned'
                                                    : 'User banned',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: Icon(
                                      user.isBanned
                                          ? Icons.check_circle
                                          : Icons.block,
                                      size: 16,
                                      color: user.isBanned
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    label: Text(
                                      user.isBanned ? 'Unban' : 'Ban',
                                      style: TextStyle(
                                        color: user.isBanned
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () async {
                                      // Open dialog for title/body and call Cloud Function sendToUids
                                      final titleController =
                                          TextEditingController();
                                      final bodyController =
                                          TextEditingController();
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            'Send Notification',
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                controller: titleController,
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: 'Title',
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: bodyController,
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: 'Message',
                                                    ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Send'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok != true) return;
                                      final title = titleController.text.trim();
                                      final body = bodyController.text.trim();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Sending notification...',
                                          ),
                                        ),
                                      );
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection('notifications')
                                            .add({
                                              'recipientId': user.id,
                                              'title': title,
                                              'body': body,
                                              'createdAt':
                                                  FieldValue.serverTimestamp(),
                                              'read': false,
                                              'type': 'admin_message',
                                            });

                                        if (!context.mounted) return;
                                        FlashMessage.show(
                                          context,
                                          message:
                                              'Notification sent to ${user.name}',
                                          type: FlashMessageType.success,
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        FlashMessage.show(
                                          context,
                                          message:
                                              'Error sending notification: $e',
                                          type: FlashMessageType.error,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.campaign,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                    label: const Text(
                                      'Send Notification',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),

                                  if (user.role == 'professor') ...[
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () async {
                                        final isApproved = user.isApproved;
                                        try {
                                          await authService.updateUserApproval(
                                            user.id,
                                            !isApproved,
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                !isApproved
                                                    ? 'Professor approved'
                                                    : 'Professor access revoked',
                                              ),
                                              backgroundColor: !isApproved
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: user.isApproved
                                              ? Colors.orange
                                              : Colors.green,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          user.isApproved
                                              ? 'REVOKE ACCESS'
                                              : 'APPROVE NOW',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedUserIds.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  onPressed: () {
                    if (currentUser != null) {
                      _assignTaskToSelected(context, currentUser);
                    }
                  },
                  label: const Text('Assign Task'),
                  icon: const Icon(Icons.assignment_add),
                  backgroundColor: Colors.blue,
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  onPressed: () async {
                    // Show dialog for title/message, then call cloud function for _selectedUserIds
                    final titleController = TextEditingController();
                    final bodyController = TextEditingController();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Send Notification to Selected'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: titleController,
                              decoration: const InputDecoration(
                                hintText: 'Title',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: bodyController,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Send'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    final title = titleController.text.trim();
                    final body = bodyController.text.trim();
                    try {
                      final firestore = FirebaseFirestore.instance;
                      final batch = firestore.batch();
                      final timestamp = FieldValue.serverTimestamp();

                      for (final uid in _selectedUserIds) {
                        final docRef = firestore
                            .collection('notifications')
                            .doc();
                        batch.set(docRef, {
                          'recipientId': uid,
                          'title': title,
                          'body': body,
                          'createdAt': timestamp,
                          'read': false,
                          'type': 'admin_message',
                        });
                      }

                      await batch.commit();

                      if (!context.mounted) return;
                      FlashMessage.show(
                        context,
                        message:
                            'Notifications sent to ${_selectedUserIds.length} users',
                        type: FlashMessageType.success,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      FlashMessage.show(
                        context,
                        message: 'Error sending notifications: $e',
                        type: FlashMessageType.error,
                      );
                    }
                    setState(() {
                      _selectedUserIds.clear();
                      _isSelectionMode = false;
                    });
                  },
                  label: const Text('Send Notification'),
                  icon: const Icon(Icons.campaign),
                  backgroundColor: Colors.green,
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: isDark
          ? Colors.blue.withAlpha(50)
          : Colors.blue.withAlpha(30),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.blue
            : (isDark ? Colors.grey[300] : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
    );
  }
}
