import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';
import 'package:eoreporter_v1/providers/auth_provider.dart';
import 'package:eoreporter_v1/screens/splash_screen.dart';
import 'package:eoreporter_v1/screens/auth/login_screen.dart';
import 'package:eoreporter_v1/screens/auth/register_screen.dart';
import 'package:eoreporter_v1/screens/home_screen.dart';
import 'package:eoreporter_v1/screens/report_outage_screen.dart';
import 'package:eoreporter_v1/screens/my_reports_screen.dart';
import 'package:eoreporter_v1/screens/feedback_screen.dart';
import 'package:eoreporter_v1/screens/notifications_screen.dart';
import 'package:eoreporter_v1/screens/profile_screen.dart';
import 'package:eoreporter_v1/screens/forgot_password_screen.dart';
import 'services/notification_polling.dart';
import 'services/local_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getInt('user_id');

  if (userId != null) {
    NotificationPoller().startPolling(userId: userId);
  }

  // Initialize local notification service first
  try {
    await LocalNotificationService().initialize();

    bool permissionsGranted =
        await LocalNotificationService().requestPermissions();
    debugPrint('Notification permissions granted: $permissionsGranted');

  } catch (e) {
    debugPrint('ERROR INITIALIZING NOTIFICATIONS: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppConstants.primaryColor),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(
            color: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
            ),
          ),
        ),
      ),
      // Define the initial route
      initialRoute: '/splash',
      // Define all the named routes
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/report': (context) => const ReportOutageScreen(),
        '/my-reports': (context) => const MyReportsScreen(),
        '/feedback': (context) => const FeedbackScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
      },
      // Handle unknown routes
      // onGenerateRoute: (settings) {
      //   // You can add custom route handling here if needed
      //   return MaterialPageRoute(
      //     builder: (context) => const Scaffold(
      //       body: Center(
      //         child: Text('Page not found'),
      //       ),
      //     ),
      //   );
      // },
    );
  }
}
