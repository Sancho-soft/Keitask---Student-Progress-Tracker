import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart' as app_models;

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Users'), elevation: 0),
      body: StreamBuilder<List<app_models.User>>(
        stream: auth.usersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final u = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: u.profileImage != null
                      ? NetworkImage(u.profileImage!)
                      : null,
                  child: u.profileImage == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(u.name),
                subtitle: Text(u.email),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    final messenger = ScaffoldMessenger.of(context);
                    if (value == 'promote') {
                      await auth.updateUserRole(u.id, 'admin');
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('User promoted to admin')),
                      );
                    } else if (value == 'demote') {
                      await auth.updateUserRole(u.id, 'user');
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('User demoted to user')),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    if (u.role != 'admin')
                      const PopupMenuItem(
                        value: 'promote',
                        child: Text('Make admin'),
                      )
                    else
                      const PopupMenuItem(
                        value: 'demote',
                        child: Text('Remove admin'),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
