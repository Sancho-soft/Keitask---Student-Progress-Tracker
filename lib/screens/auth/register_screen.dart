// keitask_management/lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'student'; // Default role
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  // Validation
  bool _validateInput() {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name.');
      return false;
    }
    if (_birthdayController.text.trim().isEmpty) {
      _showSnackBar('Please select your birthday.');
      return false;
    }
    if (_addressController.text.trim().isEmpty) {
      _showSnackBar('Please enter your address.');
      return false;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showSnackBar('Please enter your phone number.');
      return false;
    }
    // Phone number validation: Digits only
    if (!RegExp(r'^[0-9]+$').hasMatch(_phoneController.text.trim())) {
      _showSnackBar('Phone number must contain only digits.');
      return false;
    }
    if (!_emailController.text.contains('@') ||
        _emailController.text.trim().length < 5) {
      _showSnackBar('Please enter a valid email address.');
      return false;
    }
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
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _register() async {
    if (!_validateInput()) return;

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);

      if (auth.initError != null) {
        if (!mounted) return;
        _showSnackBar('Firebase error: ${auth.initError}');
        setState(() => _isLoading = false);
        return;
      }

      final user = await auth.signUpWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _selectedRole,
        profileImageFile: null, // Removed PFP upload
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );

      if (!mounted) return;
      if (user != null) {
        if (_selectedRole == 'professor') {
          // Professor flow: Show pending approval dialog then sign out
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Registration Successful'),
              content: const Text(
                'Your account has been created but requires Admin approval before you can log in.\n\nPlease wait for an administrator to approve your account.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await auth.signOut();
                    if (!mounted) return;
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Student flow: Go to Email Verification
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(user: user),
            ),
          );
        }
      } else {
        _showSnackBar('Registration failed. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Registration error: $e');
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
        _showSnackBar('Google sign-in failed');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Google sign-in error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header / Back Button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.black87),
                ),
                const SizedBox(height: 24),

                // Logo
                Center(child: _buildLogo()),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please fill in your details to sign up',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 32),

                // Form Fields
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                ),
                const SizedBox(height: 16),

                _buildDatePickerField(),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Enter your address',
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hint: 'Enter your phone number (digits only)',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Role Dropdown
                const Text(
                  'I am a:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: Colors.grey.shade400),
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
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                _buildPasswordField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a password',
                  isObscure: _obscurePassword,
                  toggleObscure: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 16),

                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  isObscure: _obscureConfirmPassword,
                  toggleObscure: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
                const SizedBox(height: 24),

                // Terms
                Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (val) =>
                          setState(() => _agreeToTerms = val ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showTermsDialog(),
                        child: const Text(
                          'I agree to the Terms and Conditions',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Separator
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

                // Google Sign In
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
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Login Link
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
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildLogo() {
    return Image.asset(
      'lib/assets/images/icons/logo_keitask.png',
      width: 120, // Smaller logo for header
      height: 120,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.task, size: 80, color: Colors.teal),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms and Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Use responsibly.\n2. Respect others.\n3. Data privacy policy applies.\n...',
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _birthdayController,
          readOnly: true,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              _birthdayController.text =
                  '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
            }
          },
          decoration: InputDecoration(
            hintText: 'MM/DD/YYYY',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[100],
            suffixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isObscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[100],
            suffixIcon: IconButton(
              icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: toggleObscure,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }
}
