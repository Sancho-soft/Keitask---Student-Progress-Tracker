import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ProfileAvatarAnimation extends StatelessWidget {
  final double size;
  final String userName;
  final bool showName;

  const ProfileAvatarAnimation({
    super.key,
    this.size = 120,
    required this.userName,
    this.showName = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Animated profile avatar
        SizedBox(
          width: size,
          height: size,
          child: Lottie.asset(
            'lib/assets/animations/Profile Avatar of Young Boy.json',
            fit: BoxFit.contain,
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 12),
          // User name below avatar
          Text(
            userName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ],
    );
  }
}
