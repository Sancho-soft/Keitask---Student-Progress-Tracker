import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../tasks/create_task_screen.dart';
import '../../widgets/flash_message.dart';

class UsersScreen extends StatefulWidget {
  final bool showBackButton;
  const UsersScreen({super.key, this.showBackButton = true});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _filter = 'all'; // 'all', 'professor', 'student'
  final Set<String> _selectedUserIds = {};
  bool _isSelectionMode = false;

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

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.appUser;
    final isProfessor = currentUser?.role == 'professor';
    final isAdmin = currentUser?.role == 'admin';

    // Force filter for professors if not already set
    if (isProfessor && _filter != 'student') {
      _filter = 'student';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedUserIds.length} Selected'
              : (isProfessor ? 'My Students' : 'Manage Users'),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
        actions: [
          if (!isProfessor && !_isSelectionMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (value) => setState(() => _filter = value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'all', child: Text('All Users')),
                const PopupMenuItem(
                  value: 'professor',
                  child: Text('Professors'),
                ),
                const PopupMenuItem(value: 'student', child: Text('Students')),
              ],
            ),
        ],
      ),
      body: StreamBuilder<List<User>>(
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

            if (_filter == 'all') return true;
            if (_filter == 'student') {
              return user.role == 'student' || user.role == 'user';
            }
            return user.role == _filter;
          }).toList();

          if (filteredUsers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No users found.', style: TextStyle(color: Colors.grey)),
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
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isSelected
                      ? const BorderSide(color: Colors.blue, width: 2)
                      : BorderSide.none,
                ),
                color: isSelected ? Colors.blue.withAlpha(20) : null,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(user.id);
                        } else if (!isProfessor) {
                          // Admin tap behavior
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
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
                                      ? Colors.purple[100]
                                      : Colors.blue[100],
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
                                        ? Colors.purple[800]
                                        : Colors.blue[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isUserProfessor && !user.isApproved) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'PENDING',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              if (user.isBanned) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'BANNED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing:
                          (!isProfessor && isUserProfessor && !user.isBanned)
                          ? Switch(
                              value: user.isApproved,
                              onChanged: (value) async {
                                try {
                                  await authService.updateUserApproval(
                                    user.id,
                                    value,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value
                                            ? 'Professor approved'
                                            : 'Professor approval revoked',
                                      ),
                                      duration: const Duration(seconds: 1),
                                      backgroundColor: value
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },
                              activeThumbColor: Colors.green,
                            )
                          : (_isSelectionMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (val) =>
                                        _toggleSelection(user.id),
                                  )
                                : null),
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
                            if (!isUserProfessor) // Only ban students (or non-professors)
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
                                        SnackBar(content: Text('Error: $e')),
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
                                final titleController = TextEditingController();
                                final bodyController = TextEditingController();
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Send Notification'),
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sending notification...'),
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
                                    message: 'Error sending notification: $e',
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
}
