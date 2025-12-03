import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../models/user_model.dart';
import '../dashboard/dashboard_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final User user; // Our app's user model

  const EmailVerificationScreen({super.key, required this.user});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool isEmailVerified = false;
  Timer? timer;
  bool canResendEmail = false;
  int _resendCountdown = 30;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    // Check if email is already verified
    isEmailVerified =
        fb_auth.FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      sendVerificationEmail();

      // Poll every 3 seconds to check for verification
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );

      // Start countdown for resend button
      startResendCountdown();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    // Reload user to get latest status
    await fb_auth.FirebaseAuth.instance.currentUser?.reload();

    setState(() {
      isEmailVerified =
          fb_auth.FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    if (isEmailVerified) {
      timer?.cancel();
      if (mounted) {
        // Navigate to dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(user: widget.user),
          ),
        );
      }
    }
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = fb_auth.FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      setState(() {
        canResendEmail = false;
        _resendCountdown = 30;
      });
      startResendCountdown();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending email: $e')));
      }
    }
  }

  void startResendCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          canResendEmail = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If already verified, show loading while redirecting
    if (isEmailVerified) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verify Email'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading:
            false, // Prevent going back without verifying
        actions: [
          TextButton(
            onPressed: () async {
              await fb_auth.FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pop(); // Go back to login/register
              }
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie Animation
            Lottie.asset(
              'lib/assets/animations/verify_email_animation.json',
              height: 200,
              repeat: true,
            ),
            const SizedBox(height: 32),

            const Text(
              'Verify your email address',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Text(
              'We have sent a verification email to:\n${fb_auth.FirebaseAuth.instance.currentUser?.email}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Waiting for verification...',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 32),

            // Resend Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: canResendEmail ? sendVerificationEmail : null,
                icon: const Icon(Icons.email),
                label: Text(
                  canResendEmail
                      ? 'Resend Email'
                      : 'Resend in ${_resendCountdown}s',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
