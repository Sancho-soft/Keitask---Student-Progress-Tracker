// lib/main.dart (MODIFIED)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart'; // Ensure this path is correct
import 'screens/auth/register_screen.dart'; // Ensure this path is correct
import 'screens/tasks/create_task_screen.dart';
import 'screens/tasks/tasks_screen.dart';
import 'screens/admin/users_screen.dart';
import 'services/task_service.dart'; // NEW IMPORT
import 'models/user_model.dart'; // For type checking in routes
import 'services/auth_service.dart';
import 'services/firestore_task_service.dart';
import 'services/notification_service.dart';
import 'services/firestore_notification_service.dart';
import 'services/theme_service.dart';

// Background handler must be a top-level function (placed after imports)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Already initialized or other issue
  }
  await NotificationService.init();
  await NotificationService.showFromRemote(message);
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Register background handler for Firebase Messaging
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    // Activate Firebase App Check using the debug provider during development.
    // This causes the App Check SDK to print a debug token in the device logs
    // which you can register in the Firebase Console under App Check -> Add Debug Token.
    try {
      if (kDebugMode) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
        );
        debugPrint('Firebase App Check: activated debug provider');
      }
    } catch (acError) {
      debugPrint('App Check activation failed: $acError');
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue anyway so UI doesn't crash; AuthService will handle gracefully
  }

  // Initialize the optional local notification system; it's guarded internally by the service
  try {
    // Provide navigatorKey to NotificationService so it can navigate on notification taps
    NotificationService.setNavigatorKey(appNavigatorKey);
    await NotificationService.init();
    await NotificationService.requestPermissions();
    // Subscribe to foreground message events and show local notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM onMessage: ${message.messageId}');
      NotificationService.showFromRemote(message);
    });
    // When the app is opened from a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM onMessageOpenedApp: ${message.messageId}');
      // Optionally navigate or handle the payload here
      // Use the navigator key + AuthService to navigate to Tasks and pass the taskId if present
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        final auth = Provider.of<AuthService>(ctx, listen: false);
        final appUser = auth.appUser;
        if (appUser != null) {
          // If data includes taskId, pass it along
          final taskId = message.data['taskId'];
          appNavigatorKey.currentState?.pushNamed(
            '/tasks',
            arguments: {'user': appUser, if (taskId != null) 'taskId': taskId},
          );
        }
      }
    });
    // If the application was launched by a notification (cold start), handle it here
    try {
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM initialMessage: ${initialMessage.messageId}');
        final ctx = appNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          final auth = Provider.of<AuthService>(ctx, listen: false);
          final user = auth.appUser;
          final taskId = initialMessage.data['taskId'];
          if (user != null) {
            appNavigatorKey.currentState?.pushNamed(
              '/tasks',
              arguments: {'user': user, if (taskId != null) 'taskId': taskId},
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error handling initial FCM message: $e');
    }
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('FCM token: $token');
  } catch (e) {
    debugPrint('NotificationService initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FirestoreTaskService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        Provider(create: (_) => FirestoreNotificationService()),
      ],
      child: MyApp(navigatorKey: appNavigatorKey),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const MyApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'KeiTask',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Outfit',
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFFB3E5FC),
              surface: const Color(0xFFFFFFFF),
            ).copyWith(
              primary: const Color(0xFF42A5F5),
              secondary: const Color(0xFF90CAF9),
              primaryContainer: const Color(0xFFEFF8FF),
            ),
        scaffoldBackgroundColor: const Color(0xFFEFF8FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFEFF8FF),
          foregroundColor: Color(0xFF0F1724),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0F1724)),
        ),
        textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'Outfit',
          bodyColor: const Color(0xFF0F1724),
          displayColor: const Color(0xFF0F1724),
        ),
        cardColor: const Color(0xFFFFFFFF),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5EA8FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF222831),
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xFF00ADB5), // Teal for primary action
              secondary: const Color(0xFF00FFF5),
              primaryContainer: const Color(0xFF393E46),
            ),
        scaffoldBackgroundColor: const Color(0xFF222831),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF222831),
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        cardColor: const Color(0xFF393E46),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF00ADB5), // Teal color for actions
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00ADB5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      themeMode: Provider.of<ThemeService>(context).themeMode,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) {
          final user = ModalRoute.of(context)?.settings.arguments as User;
          return DashboardScreen(user: user);
        },
        '/tasks': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is User) {
            return TasksScreen(user: args);
          }
          if (args is Map && args['user'] is User) {
            return TasksScreen(user: args['user'] as User);
          }
          // As a fallback, use currently signed in user from AuthService
          final currentUser = Provider.of<AuthService>(
            context,
            listen: false,
          ).appUser;
          if (currentUser != null) return TasksScreen(user: currentUser);
          // If no user, navigate to Login - empty placeholder
          return const LoginScreen();
        },
        '/create-task': (context) {
          return const CreateTaskScreen();
        },
        '/admin/users': (context) {
          return const UsersScreen();
        },
      },
      builder: (context, child) {
        final theme = Provider.of<ThemeService>(context);
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(theme.textScaleFactor)),
          child: child!,
        );
      },
    );
  }
}
