// keitask_management/lib/screens/auth/register_screen.dart (MODIFIED)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../widgets/registration_success_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0;

  // Step 1: Personal Information
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'student'; // Default role

  // Step 2: Email
  final _emailController = TextEditingController();

  // Step 3: Password
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  bool _isLoading = false;
  File? _profileImageFile;
  bool _isPickingImage = false;

  // --- VALIDATION AND NAVIGATION ---

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Personal Info
        if (_nameController.text.trim().isEmpty ||
            _birthdayController.text.trim().isEmpty) {
          _showSnackBar('Please fill in Name and Birthday.');
          return false;
        }
        return true;
      case 1: // Email
        if (!_emailController.text.contains('@') ||
            _emailController.text.trim().length < 5) {
          _showSnackBar('Please enter a valid email address.');
          return false;
        }
        return true;
      case 2: // Password
        if (_passwordController.text.length < 6) {
          _showSnackBar('Password must be at least 6 characters.');
          return false;
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          _showSnackBar('Passwords do not match.');
          return false;
        }
        if (!_agreeToTerms) {
          _showSnackBar('You must agree to the Terms and Conditions.');
          return false;
        }
        return true;
      case 3: // Photo (optional)
        // Photo step is optional — allow skipping or continuing with/without photo
        return true;
      default:
        return true;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _register() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);

      // Check if AuthService detected an init error
      if (auth.initError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase error: ${auth.initError}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final user = await auth.signUpWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _selectedRole,
        profileImageFile: _profileImageFile,
      );
      if (!mounted) return;
      if (user != null) {
        if (_selectedRole == 'professor') {
          // Professor flow: Show pending approval dialog then sign out
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Registration Successful'),
              content: const Text(
                'Your account has been created but requires Admin approval before you can log in.\n\nPlease wait for an administrator to approve your account.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog
                    await auth.signOut(); // Sign out immediately
                    if (!mounted) return;
                    Navigator.pop(context); // Go back to Login Screen
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Student flow: Show success animation and login
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => RegistrationSuccessDialog(
              onComplete: () {
                // Navigate back to login after animation completes
                Navigator.of(context).pop(); // Close dialog
                Navigator.pop(context); // Go back to Login Screen
              },
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = await auth.signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        Navigator.of(
          context,
        ).pushReplacementNamed('/dashboard', arguments: user);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;

    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    if (_isPickingImage) return; // prevent re-entrancy
    _isPickingImage = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
      );
      if (picked != null && mounted) {
        setState(() => _profileImageFile = File(picked.path));
      }
    } on Exception catch (e) {
      // Surface a friendly message using a captured messenger
      messenger.showSnackBar(
        SnackBar(content: Text('Image selection failed: ${e.toString()}')),
      );
    } finally {
      _isPickingImage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button and Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      GestureDetector(
                        onTap: _previousStep,
                        child: const Icon(Icons.arrow_back),
                      )
                    else
                      // Use a Spacer or SizedBox for alignment if the back button is missing
                      const SizedBox.shrink(),

                    // Step Indicator (X of 4)
                    Text(
                      '${_currentStep + 1} of 4',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Logo (only on first step, matching Figma/Login)
                if (_currentStep == 0)
                  Center(
                    child: Column(
                      children: [_buildLogo(), const SizedBox(height: 32)],
                    ),
                  ),

                // Step Content Title
                Text(
                  _getStepTitle(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Progress Bar (Black) - 4 steps total now
                LinearProgressIndicator(
                  value: (_currentStep + 1) / 4,
                  minHeight: 3,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                  borderRadius: BorderRadius.circular(1.5),
                ),
                const SizedBox(height: 32),

                // Step 1: Personal Information
                if (_currentStep == 0) ...[
                  _buildTextField(
                    controller: _nameController,
                    label: 'Name',
                    hint: 'Enter your full name',
                  ),
                  const SizedBox(height: 24),

                  _buildDatePickerField(),
                  const SizedBox(height: 24),

                  _buildTextField(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'Enter your address',
                  ),
                  const SizedBox(height: 24),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone No.',
                    hint: 'Enter your phone number',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),

                  // Role Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'I am a:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRole,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'student',
                                child: Text('Student'),
                              ),
                              DropdownMenuItem(
                                value: 'professor',
                                child: Text('Professor'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedRole = value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ]
                // Step 2: Email
                else if (_currentStep == 1) ...[
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ]
                // Step 3: Password
                else if (_currentStep == 2) ...[
                  _buildPasswordField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Create a password',
                    isObscure: _obscurePassword,
                    toggleObscure: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hint: 'Confirm your password',
                    isObscure: _obscureConfirmPassword,
                    toggleObscure: () {
                      setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Terms and Conditions
                  Row(
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (value) {
                          setState(() => _agreeToTerms = value ?? false);
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'I agree to the Terms and Conditions',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Terms and Conditions'),
                              content: const SingleChildScrollView(
                                child: Text(
                                  'Here are the terms and conditions...\n\n1. Use the app responsibly.\n2. Do not share your password.\n3. Respect other users.\n\n(This is a placeholder for actual terms)',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('Read'),
                      ),
                    ],
                  ),
                ],
                // Step 4: Profile Photo (optional)
                if (_currentStep == 3)
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickProfileImage,
                          child: CircleAvatar(
                            radius: 48,
                            backgroundImage: _profileImageFile != null
                                ? FileImage(_profileImageFile!) as ImageProvider
                                : null,
                            child: _profileImageFile == null
                                ? const Icon(Icons.camera_alt, size: 36)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            // Skip profile photo and submit registration
                            _register();
                          },
                          child: const Text('Skip for now'),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // Navigation Buttons
                Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _currentStep < 3
                            ? _nextStep
                            : (_isLoading ? null : _register),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                _currentStep < 3 ? 'Next' : 'Sign up',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Sign In / Google Buttons (only on first step, matching Figma)
                if (_currentStep == 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: SvgPicture.asset(
                              'assets/images/icons8-google.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Continue with Google',
                            style: TextStyle(fontSize: 14, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Create Account';
      case 1:
        return "What's your email?";
      case 2:
        return 'Create a Password';
      default:
        return 'Register';
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87, // Fixed faded label
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          keyboardType: keyboardType,
        ),
      ],
    );
  }

  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Birthday',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87, // Fixed faded label
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _birthdayController,
          decoration: InputDecoration(
            hintText: 'MM/DD/YYYY',
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          readOnly: true,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              _birthdayController.text =
                  '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
            }
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isObscure,
    required VoidCallback toggleObscure,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87, // Fixed faded label
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isObscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            suffixIcon: IconButton(
              icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: toggleObscure,
            ),
          ),
        ),
      ],
    );
  }

  // Logo builder using image asset
  Widget _buildLogo() {
    return Image.asset(
      'lib/assets/images/icons/logo_keitask.png',
      width: 250,
      height: 250,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.task, size: 200, color: Colors.teal);
      },
    );
  }
}
