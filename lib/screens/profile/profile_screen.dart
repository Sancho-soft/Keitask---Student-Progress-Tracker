// lib/screens/auth/profile/profile_screen.dart (PREMIUM OVERHAUL)

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/firestore_task_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../services/report_service.dart';

// --- Custom Clipper for Curved Header ---
class ProfileHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class ProfileScreen extends StatelessWidget {
  final User user;
  final VoidCallback onBackToHome;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthService>(context);
    final displayUser = auth.appUser ?? user;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow body to flow behind app bar
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 20),
            ),
            onPressed: () => _showEditProfileDialog(context, displayUser),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Curved Header with User Info ---
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. Curved Background
                ClipPath(
                  clipper: ProfileHeaderClipper(),
                  child: Container(
                    height: 420, // INCREASE HEIGHT FURTHER (Was 380)
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00ADB5), // Teal
                          const Color(0xFF393E46), // Dark Grey
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // 2. Profile Content (Avatar + Name)
                Positioned(
                  top: 90, // Moved up slightly
                  child: Column(
                    children: [
                      // Avatar with Glow
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(60),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: theme.colorScheme.surface,
                            backgroundImage:
                                displayUser.profileImage != null &&
                                    displayUser.profileImage!.isNotEmpty
                                ? NetworkImage(displayUser.profileImage!)
                                : null,
                            child:
                                (displayUser.profileImage == null ||
                                    displayUser.profileImage!.isEmpty)
                                ? Text(
                                    displayUser.name.isNotEmpty
                                        ? displayUser.name[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayUser.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayUser.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          displayUser.role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color:
                                theme.colorScheme.primary, // Teal text on White
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 3. Floating Stats Card
                Positioned(
                  bottom: -50,
                  left: 20,
                  right: 20,
                  child: _buildStatsCard(context, displayUser),
                ),
              ],
            ),
            const SizedBox(height: 60),

            // --- Info & Settings Section ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal Details Group
                  Text(
                    'Personal Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(
                            isDark ? 50 : 10,
                          ), // Softer shadow
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoTile(
                          context,
                          icon: Icons.phone,
                          label: 'Phone',
                          value: displayUser.phoneNumber ?? 'Not set',
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          color: theme.dividerColor.withAlpha(50),
                        ),
                        _buildInfoTile(
                          context,
                          icon: Icons.location_on,
                          label: 'Address',
                          value: displayUser.address ?? 'Not set',
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          color: theme.dividerColor.withAlpha(50),
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          color: theme.dividerColor.withAlpha(50),
                        ),
                        // Always show, try fallback
                        _buildMemberSinceTile(context, displayUser),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Settings Group
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      _buildSettingItem(
                        context,
                        icon: Icons.lock_outline,
                        label: 'Change Password',
                        onTap: () => _showChangePasswordDialog(context),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        context,
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        onTap: () => _showNotificationSettingsDialog(context),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        context,
                        icon: Icons.tune,
                        label: 'System Preferences',
                        onTap: () => _showSystemPreferencesDialog(context),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        context,
                        icon: Icons.bug_report_outlined,
                        label: 'Report a Problem',
                        onTap: () => _showReportDialog(context),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        context,
                        icon: Icons.logout,
                        label: 'Log Out',
                        color: Colors.redAccent,
                        onTap: () => _showLogoutDialog(context),
                        isDestructive: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildStatsCard(BuildContext context, User displayUser) {
    final theme = Theme.of(context);
    final isProfessor = displayUser.role.toLowerCase() == 'professor';
    final isAdmin = displayUser.role.toLowerCase().contains('admin');
    final isStudent = !isProfessor && !isAdmin;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: StreamBuilder<List<Task>>(
        stream: Provider.of<FirestoreTaskService>(
          context,
          listen: false,
        ).tasksStream(),
        builder: (context, snapshot) {
          final tasks = snapshot.data ?? [];

          // STUDENT VIEW: Completed | Points
          if (isStudent) {
            int completed = tasks
                .where(
                  (t) =>
                      t.assignees.contains(displayUser.id) &&
                      t.status.toLowerCase() == 'completed',
                )
                .length;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(context, '$completed', 'Complete'),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.withAlpha(50),
                ),
                _buildStatItem(context, '${displayUser.points}', 'Points'),
              ],
            );
          }
          // PROFESSOR / ADMIN VIEW: Tasks Created
          else {
            int created = tasks
                .where((t) => t.creator == displayUser.id)
                .length;
            return Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Single item centered
              children: [_buildStatItem(context, '$created', 'Tasks Created')],
            );
          }
        },
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSinceTile(BuildContext context, User displayUser) {
    DateTime? date = displayUser.createdAt;

    // Fallback: Check AuthService for Firebase Metadata if Firestore date is missing
    if (date == null) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.firebaseUser != null) {
        date = auth.firebaseUser!.metadata.creationTime;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: Colors.grey, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Member Since',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  date != null ? _formatDate(date) : 'Unknown',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final effectiveColor =
        color ?? (isDestructive ? Colors.red : theme.colorScheme.onSurface);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDestructive
                  ? Colors.red.withAlpha(30)
                  : Colors.grey.withAlpha(20),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.withAlpha(20)
                      : theme.colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDestructive ? Colors.red : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: effectiveColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey.withAlpha(100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // --- Dialog Methods (Existing functionality maintained) ---

  void _showReportDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'bug';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Report a Problem'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please describe the issue you are facing.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  onChanged: (value) => setState(() => selectedType = value!),
                  items: const [
                    DropdownMenuItem(value: 'bug', child: Text('Bug')),
                    DropdownMenuItem(
                      value: 'login_error',
                      child: Text('Login Error'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Brief summary',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Detailed explanation...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
              onPressed: isLoading
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty ||
                          descriptionController.text.trim().isEmpty) {
                        return;
                      }
                      setState(() => isLoading = true);
                      try {
                        final reportService = ReportService();
                        final authUser = Provider.of<AuthService>(
                          context,
                          listen: false,
                        ).appUser;
                        if (authUser != null) {
                          await reportService.createReport(
                            user: authUser,
                            title: titleController.text.trim(),
                            description: descriptionController.text.trim(),
                            type: selectedType,
                          );
                          if (context.mounted) Navigator.pop(context);
                        }
                      } finally {
                        if (context.mounted) setState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, User displayUser) {
    final nameController = TextEditingController(text: displayUser.name);
    final phoneController = TextEditingController(
      text: displayUser.phoneNumber,
    );
    final addressController = TextEditingController(text: displayUser.address);
    bool isLoading = false;
    bool isPickingImage = false;
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          double uploadProgress = 0.0;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (isPickingImage) return;
                      setState(() => isPickingImage = true);
                      try {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 512,
                          maxHeight: 512,
                        );
                        if (pickedFile != null) {
                          setState(() => selectedImage = File(pickedFile.path));
                        }
                      } finally {
                        setState(() => isPickingImage = false);
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: selectedImage != null
                          ? FileImage(selectedImage!)
                          : (displayUser.profileImage != null &&
                                        displayUser.profileImage!.isNotEmpty
                                    ? NetworkImage(displayUser.profileImage!)
                                    : null)
                                as ImageProvider?,
                      child:
                          selectedImage == null &&
                              (displayUser.profileImage == null ||
                                  displayUser.profileImage!.isEmpty)
                          ? const Icon(Icons.camera_alt)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (uploadProgress > 0 && uploadProgress < 1)
                    LinearProgressIndicator(value: uploadProgress),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.withAlpha(50)),
                  Container(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _showDeleteAccountDialog(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.withAlpha(50)),
                        ),
                      ),
                      icon: const Icon(Icons.delete_forever, size: 20),
                      label: const Text('Delete Account'),
                    ),
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
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() => isLoading = true);
                        try {
                          final auth = Provider.of<AuthService>(
                            context,
                            listen: false,
                          );
                          String? imageUrl;
                          if (selectedImage != null) {
                            imageUrl = await auth
                                .uploadProfileImageToCloudinary(
                                  selectedImage!,
                                  onProgress: (p) =>
                                      setState(() => uploadProgress = p),
                                );
                          }
                          await auth.updateUserName(nameController.text.trim());
                          await auth.updateUserPhone(
                            phoneController.text.trim(),
                          );
                          await auth.updateUserAddress(
                            addressController.text.trim(),
                          );
                          if (imageUrl != null) {
                            await auth.updateUserProfileImage(imageUrl);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
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
              onPressed: isLoading
                  ? null
                  : () async {
                      if (newPasswordController.text !=
                          confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('New passwords do not match'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (newPasswordController.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password must be at least 6 characters',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);
                      try {
                        final auth = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );
                        // Note: Re-authentication often required here in real apps
                        await auth.changePassword(
                          newPasswordController.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) setState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettingsDialog(BuildContext context) {
    bool emailNotifications = true;
    bool pushNotifications = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Notifications'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Email Notifications'),
                subtitle: const Text('Receive updates via email'),
                value: emailNotifications,
                onChanged: (val) => setState(() => emailNotifications = val),
              ),
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Receive alerts on your device'),
                value: pushNotifications,
                onChanged: (val) => setState(() => pushNotifications = val),
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
                // In a real app, save these preferences to Firestore/Local Storage
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification settings saved')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSystemPreferencesDialog(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    var darkMode = themeService.themeMode == ThemeMode.dark;
    String textSize = 'normal';
    if (themeService.textScaleFactor < 0.9) {
      textSize = 'small';
    } else if (themeService.textScaleFactor > 1.1) {
      textSize = 'large';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('System Preferences'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: darkMode,
                onChanged: (val) => setState(() => darkMode = val),
              ),
              const SizedBox(height: 16),
              const Text(
                'Text Size',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'small', label: Text('Small')),
                  ButtonSegment(value: 'normal', label: Text('Normal')),
                  ButtonSegment(value: 'large', label: Text('Large')),
                ],
                selected: {textSize},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => textSize = newSelection.first);
                },
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
                themeService.setThemeMode(
                  darkMode ? ThemeMode.dark : ThemeMode.light,
                );
                themeService.setTextScale(textSize);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Reset theme to light mode before logging out
              Provider.of<ThemeService>(
                context,
                listen: false,
              ).setThemeMode(ThemeMode.light);

              Navigator.pop(context);
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
              Provider.of<AuthService>(context, listen: false).signOut();
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    bool isLoading = false;
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.red),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Are you sure? This action CANNOT be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'All your data (tasks, submissions, profile) will be permanently removed.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => obscurePassword = !obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              TextButton(
                onPressed: () async {
                  if (passwordController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your password to confirm.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() => isLoading = true);
                  try {
                    // 1. Verify Password
                    await Provider.of<AuthService>(
                      context,
                      listen: false,
                    ).reauthenticate(passwordController.text.trim());

                    // 2. Perform Delete
                    await Provider.of<AuthService>(
                      context,
                      listen: false,
                    ).deleteAccount();

                    if (context.mounted) {
                      Navigator.pop(context); // Close Dialog
                      // Navigate to splash/login and remove all routes
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setState(() => isLoading = false);
                      // Do not close dialog, let them fix password
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Delete Forever',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
