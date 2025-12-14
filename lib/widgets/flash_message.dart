import 'package:flutter/material.dart';

enum FlashMessageType { success, error, info, warning }

class FlashMessage {
  static void show(
    BuildContext context, {
    required String message,
    FlashMessageType type = FlashMessageType.info,
  }) {
    final color = _getColor(type);
    final icon = _getIcon(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static Color _getColor(FlashMessageType type) {
    switch (type) {
      case FlashMessageType.success:
        return Colors.green.shade600;
      case FlashMessageType.error:
        return Colors.red.shade600;
      case FlashMessageType.warning:
        return Colors.orange.shade700;
      case FlashMessageType.info:
        return Colors.blue.shade600;
    }
  }

  static IconData _getIcon(FlashMessageType type) {
    switch (type) {
      case FlashMessageType.success:
        return Icons.check_circle_outline;
      case FlashMessageType.error:
        return Icons.error_outline;
      case FlashMessageType.warning:
        return Icons.warning_amber_rounded;
      case FlashMessageType.info:
        return Icons.info_outline;
    }
  }
}
