// lib/services/notification_service.dart
// Centralized wrapper around flutter_local_notifications
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:keitask_management/models/task_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool supported = false;

  NotificationService._();

  /// Optional navigator key to allow navigation when the user taps
  /// on a local notification's action. It is set by the app at startup.
  static GlobalKey<NavigatorState>? navigatorKey;
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  /// Optional callback to handle notification taps (payload: string)
  static void Function(String? payload)? onNotificationTap;
  static void setOnNotificationTap(void Function(String? payload)? cb) {
    onNotificationTap = cb;
  }

  static Future<void> init() async {
    // Do not attempt to initialize for web
    if (kIsWeb) {
      supported = false;
      return;
    }

    // Limiting to likely supported platforms for a conservative approach
    final platform = defaultTargetPlatform;
    if (!(platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows)) {
      supported = false;
      return;
    }

    final androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final iosSettings = DarwinInitializationSettings();
    final macSettings = DarwinInitializationSettings();

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macSettings,
    );

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse r) {
          debugPrint(
            'NotificationService: onDidReceiveNotificationResponse payload=${r.payload}',
          );
          try {
            // If the app registered a handler, call it
            if (onNotificationTap != null) {
              onNotificationTap!(r.payload);
              return;
            }
            // If no callback provided, attempt to navigate using a saved navigator key
            if (navigatorKey?.currentState != null) {
              final payload = r.payload;
              if (payload != null && payload.isNotEmpty) {
                // If payload is a simple taskId string
                navigatorKey!.currentState!.pushNamed(
                  '/tasks',
                  arguments: {'taskId': payload},
                );
              } else {
                navigatorKey!.currentState!.pushNamed('/tasks');
              }
            }
          } catch (e) {
            debugPrint('Notification tap handler error: $e');
          }
        },
      );
      supported = true;
      debugPrint('NotificationService: plugin initialized successfully');
      // Create Android notification channel(s)
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        const taskChannel = AndroidNotificationChannel(
          'task_channel',
          'Task Assignments',
          description: 'Notifications for new task assignments',
          importance: Importance.high,
        );
        await androidPlugin.createNotificationChannel(taskChannel);
        const fcmChannel = AndroidNotificationChannel(
          'fcm_channel',
          'FCM Notifications',
          description: 'Notifications received from FCM',
          importance: Importance.high,
        );
        await androidPlugin.createNotificationChannel(fcmChannel);
        const generalChannel = AndroidNotificationChannel(
          'general_channel',
          'General Notifications',
          description: 'General app notifications',
          importance: Importance.high,
        );
        await androidPlugin.createNotificationChannel(generalChannel);
      }
    } catch (e) {
      supported = false;
      debugPrint('NotificationService: initialize failed - $e');
    }
  }

  // Request user permissions for notification behavior (iOS + Android 13+)
  static Future<void> requestPermissions() async {
    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    try {
      // Request general notification permission with FirebaseMessaging
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('Notification permission settings: $settings');
    } catch (e) {
      debugPrint('Error requesting firebase messaging permission: $e');
    }

    // Request Android 13 POST_NOTIFICATIONS runtime permission if needed
    if (platform == TargetPlatform.android) {
      try {
        if (await Permission.notification.isDenied) {
          final result = await Permission.notification.request();
          debugPrint('Permission.notification result: $result');
        }
      } catch (e) {
        debugPrint('Error requesting notification permission (Android): $e');
      }
    }
  }

  static Future<void> showTaskNotification(Task task) async {
    if (!supported) return;

    const androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Task Assignments',
      channelDescription: 'Notifications for new task assignments',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDarwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDarwinDetails,
      macOS: iosDarwinDetails,
    );

    try {
      await _plugin.show(
        task.hashCode,
        'New Task Assigned',
        'You have been assigned: ${task.title}',
        details,
        payload: task.id,
      );
    } catch (e) {
      // Swallow exceptions from the plugin to avoid crashing the app
    }
  }

  static Future<void> showGeneralNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!supported) return;

    const androidDetails = AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDarwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDarwinDetails,
      macOS: iosDarwinDetails,
    );

    try {
      await _plugin.show(id, title, body, details, payload: 'general');
    } catch (e) {
      debugPrint('NotificationService: showGeneralNotification failed - $e');
    }
  }

  // Show a local notification from a Firebase RemoteMessage or generic payload
  static Future<void> showFromRemote(RemoteMessage message) async {
    if (!supported) return;
    final title =
        message.notification?.title ??
        message.data['title'] ??
        'New Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    const androidDetails = AndroidNotificationDetails(
      'fcm_channel',
      'FCM Notifications',
      channelDescription: 'Notifications from Firebase Cloud Messaging',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDarwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDarwinDetails,
      macOS: iosDarwinDetails,
    );

    final payload =
        message.data['taskId'] ?? message.data['taskID'] ?? message.data['id'];
    try {
      await _plugin.show(
        title.hashCode ^ body.hashCode,
        title,
        body,
        details,
        payload: payload?.toString(),
      );
    } catch (e) {
      debugPrint('NotificationService.showFromRemote error: $e');
    }
  }
}
