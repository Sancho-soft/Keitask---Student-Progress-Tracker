// lib/main.dart (MODIFIED)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/dashboard/dashboard_screen.dart'; // Ensure this path is correct
import 'screens/auth/register_screen.dart'; // Ensure this path is correct
import 'screens/auth/tasks/create_task_screen.dart';
import 'screens/auth/tasks/tasks_screen.dart';
import 'screens/admin/users_screen.dart';
import 'services/task_service.dart'; // NEW IMPORT
import 'models/user_model.dart'; // For type checking in routes
import 'services/auth_service.dart';
import 'services/firestore_task_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FirestoreTaskService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KeiTask Student Progress Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
              primary: const Color(0xFF222831),
              secondary: const Color(0xFF393E46),
              primaryContainer: const Color(0xFF1E2933),
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
          final user = ModalRoute.of(context)?.settings.arguments as User;
          return TasksScreen(user: user);
        },
        '/create-task': (context) {
          return const CreateTaskScreen();
        },
        '/admin/users': (context) {
          return const UsersScreen();
        },
      },
    );
  }
}
