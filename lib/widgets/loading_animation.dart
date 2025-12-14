import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingAnimation extends StatelessWidget {
  final String message;
  final double size;
  final bool showMessage;

  const LoadingAnimation({
    super.key,
    this.message = 'Loading...',
    this.size = 100,
    this.showMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading spinner
          SizedBox(
            width: size,
            height: size,
            child: Lottie.asset(
              'lib/assets/animations/Insider-loading.json',
              repeat: true,
              reverse: false,
            ),
          ),
          if (showMessage) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}
