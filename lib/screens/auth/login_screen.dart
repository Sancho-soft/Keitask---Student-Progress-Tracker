import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/flash_message.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'forgot_password_screen.dart';
import '../../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      FlashMessage.show(
        context,
        message: 'Please enter email and password',
        type: FlashMessageType.warning,
      );
      return;
    }

    // Basic email format validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      FlashMessage.show(
        context,
        message: 'Please enter a valid email address (e.g. name@example.com)',
        type: FlashMessageType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final navigator = Navigator.of(context);
      final appUser = await auth.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      if (appUser != null) {
        navigator.pushReplacementNamed('/dashboard', arguments: appUser);
      } else {
        FlashMessage.show(
          context,
          message: 'Login failed. Please check your credentials.',
          type: FlashMessageType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        FlashMessage.show(
          context,
          message:
              'Login error: ${e.toString().replaceAll("Exception:", "").trim()}',
          type: FlashMessageType.error,
        );
      }
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
        FlashMessage.show(
          context,
          message: 'Google sign in failed',
          type: FlashMessageType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      FlashMessage.show(
        context,
        message: 'Google sign-in error: ${e.toString()}',
        type: FlashMessageType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(
        context,
      ).scaffoldBackgroundColor, // Adaptive background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                // Removed MainAxisAlignment.center to allow manual spacing from top
                children: [
                  // Logo Section - Using Image Asset
                  _buildLogo(),
                  const SizedBox(height: 24),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'Enter your email address',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 24),
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Enter your password',
                          isPassword: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Log In Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
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
                          : const Text(
                              'Log in',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Forgot Password Link - CENTERED
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Divider with "or"
                  Row(
                    children: [
                      Expanded(
                        child: Divider(thickness: 1, color: Colors.grey[200]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(thickness: 1, color: Colors.grey[200]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Continue with Google Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.blue, width: 1),
                        backgroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Using a smaller container for the icon to ensure keyline alignment
                          SizedBox(
                            width: 24,
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
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Navigate to the register screen
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text(
                          ' Sign up',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/icons/logo_keitask.png',
      width: 300,
      height: 300,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.task, size: 100, color: Colors.teal);
      },
    );
  }
}
