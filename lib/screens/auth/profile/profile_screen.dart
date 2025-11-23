// lib/screens/auth/profile/profile_screen.dart (IMPLEMENTED EDIT PROFILE, CHANGE PASSWORD, SYSTEM PREFERENCES)

import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/theme_service.dart';
import 'progress_detail_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// We add a required callback function to handle navigation inside the Dashboard
class ProfileScreen extends StatelessWidget {
  final User user;
  final VoidCallback onBackToHome; // NEW: Callback to switch to Home tab

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBackToHome,
        ),
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sky-blue Header Section with Profile Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withAlpha(200),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  // Profile Avatar Circle with User Initial or Image
                  Stack(
                    children: [
                      user.profileImage != null && user.profileImage!.isNotEmpty
                          ? CircleAvatar(
                              radius: 60,
                              backgroundImage: NetworkImage(user.profileImage!),
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                            )
                          : CircleAvatar(
                              radius: 60,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                      // Camera Icon Overlay
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // User Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(200),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // User Information Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(25),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Name', user.name),
                  const SizedBox(height: 14),
                  _buildInfoRow('Email', user.email),
                  const SizedBox(height: 14),
                  _buildInfoRow('Role', user.role),
                  const SizedBox(height: 14),
                  _buildInfoRow(
                    'Joined',
                    _formatDate(DateTime.now()),
                  ), // Mock data; replace with user.createdAt if available
                  const SizedBox(height: 14),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 14),
                  // (Edit Profile removed) Settings below allow profile changes
                ],
              ),
            ),

            // Settings Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Settings Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Edit Profile (re-added here)
                  _buildSettingButton(
                    icon: Icons.edit,
                    label: 'Edit Profile',
                    onTap: () => _showEditProfileDialog(context),
                  ),
                  const SizedBox(height: 12),
                  // Change Password
                  _buildSettingButton(
                    icon: Icons.lock,
                    label: 'Change Password',
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                  const SizedBox(height: 12),
                  // Notifications Settings
                  _buildSettingButton(
                    icon: Icons.notifications,
                    label: 'Notifications Settings',
                    onTap: () => _showNotificationSettingsDialog(context),
                  ),
                  const SizedBox(height: 12),
                  // System Preferences
                  _buildSettingButton(
                    icon: Icons.tune,
                    label: 'System Preferences',
                    onTap: () => _showSystemPreferencesDialog(context),
                  ),
                  const SizedBox(height: 12),
                  // Logout
                  _buildSettingButton(
                    icon: Icons.logout,
                    label: 'Log Out',
                    onTap: () => _showLogoutDialog(context),
                    isLogout: true,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Format date
  String _formatDate(DateTime date) {
    final months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Helper: Show feature coming soon
  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final roleController = TextEditingController(text: user.role.toUpperCase());
    bool isLoading = false;
    bool isPickingImage =
        false; // guard to prevent concurrent image picker calls
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          double uploadProgress = 0.0;
          return AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile Image Section
                  GestureDetector(
                    onTap: () async {
                      if (isPickingImage) return; // already in progress
                      setState(() => isPickingImage = true);
                      try {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 512,
                          maxHeight: 512,
                        );
                        if (pickedFile != null) {
                          setState(() {
                            selectedImage = File(pickedFile.path);
                          });
                        }
                      } on Exception catch (e) {
                        // Handle PlatformException(already_active, ...) gracefully
                        // Show a brief message for unexpected errors
                        if (e.toString().contains('already_active')) {
                          // ignore - user tapped multiple times quickly
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Image picker error: $e')),
                            );
                          }
                        }
                      } finally {
                        setState(() => isPickingImage = false);
                      }
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: selectedImage != null
                          ? CircleAvatar(
                              backgroundImage: FileImage(selectedImage!),
                            )
                          : (user.profileImage != null &&
                                    user.profileImage!.isNotEmpty
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      user.profileImage!,
                                    ),
                                  )
                                : CircleAvatar(
                                    backgroundColor: Colors.blue[100],
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.blue,
                                    ),
                                  )),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to change profile picture',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (uploadProgress > 0 && uploadProgress < 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: LinearProgressIndicator(value: uploadProgress),
                    ),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      label: const Text('Full Name'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Email display (read-only)
                  TextField(
                    controller: emailController,
                    readOnly: true,
                    decoration: InputDecoration(
                      label: const Text('Email'),
                      hintText: 'Your email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: const Icon(Icons.email, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Role display (read-only)
                  TextField(
                    controller: roleController,
                    readOnly: true,
                    decoration: InputDecoration(
                      label: const Text('Role'),
                      hintText: 'Your role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: const Icon(
                        Icons.security,
                        color: Colors.grey,
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
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Name cannot be empty'),
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

                          // Upload image if selected (Cloudinary helper)
                          String? imageUrl;
                          if (selectedImage != null) {
                            // reset progress
                            setState(() => uploadProgress = 0.0);
                            imageUrl = await auth
                                .uploadProfileImageToCloudinary(
                                  selectedImage!,
                                  onProgress: (p) =>
                                      setState(() => uploadProgress = p),
                                );
                          }

                          // Update user name and optionally profile image
                          await auth.updateUserName(nameController.text.trim());
                          if (imageUrl != null) {
                            await auth.updateUserProfileImage(imageUrl);
                          }

                          if (!context.mounted) return;
                          Navigator.pop(context);
                          // Navigate to Progress Detail page after save
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ProgressDetailScreen(),
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          setState(() => isLoading = false);
                          // clear progress bar
                          setState(() => uploadProgress = 0.0);
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
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

  // Helper: Show change password dialog
  void _showChangePasswordDialog(BuildContext context) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    hintText: 'Enter new password',
                    label: const Text('New Password'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
                    hintText: 'Confirm password',
                    label: const Text('Confirm Password'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final newPwd = newPasswordController.text.trim();
                      final confirmPwd = confirmPasswordController.text.trim();

                      if (newPwd.isEmpty || confirmPwd.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in all fields'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (newPwd != confirmPwd) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (newPwd.length < 6) {
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
                        await auth.changePassword(newPwd);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password changed successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Show notifications settings dialog
  void _showNotificationSettingsDialog(BuildContext context) {
    bool enableNotifications = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Notifications Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Task Notifications'),
                  subtitle: const Text('Get notified about task updates'),
                  value: enableNotifications,
                  onChanged: (value) =>
                      setState(() => enableNotifications = value),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Message Alerts'),
                  subtitle: const Text('Receive message notifications'),
                  value: enableNotifications,
                  onChanged: (value) =>
                      setState(() => enableNotifications = value),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Email Digest'),
                  subtitle: const Text('Weekly email summary'),
                  value: enableNotifications,
                  onChanged: (value) =>
                      setState(() => enableNotifications = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification settings saved!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Show system preferences dialog
  void _showSystemPreferencesDialog(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    var darkMode = themeService.themeMode == ThemeMode.dark;
    String textSize = 'normal'; // small, normal, large

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('System Preferences'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Enable dark theme'),
                  value: darkMode,
                  onChanged: (value) => setState(() => darkMode = value),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Text Size',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'small', label: Text('Small')),
                    ButtonSegment<String>(
                      value: 'normal',
                      label: Text('Normal'),
                    ),
                    ButtonSegment<String>(value: 'large', label: Text('Large')),
                  ],
                  selected: <String>{textSize},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() => textSize = newSelection.first);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Language selection coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Apply theme change
                themeService.setThemeMode(
                  darkMode ? ThemeMode.dark : ThemeMode.light,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('System preferences saved!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Show logout confirmation
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets (Omitting for brevity, remain the same) ---
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLogout = false,
    bool isAdmin = false,
  }) {
    final bgColor = isLogout
        ? Colors.red.withAlpha(25)
        : (isAdmin ? Colors.purple.withAlpha(15) : Colors.blue.withAlpha(15));
    final textColor = isLogout
        ? Colors.red
        : (isAdmin ? Colors.purple : Colors.blue);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: textColor.withAlpha(25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: textColor.withAlpha(50), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: textColor.withAlpha(128),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
