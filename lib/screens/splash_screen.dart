import 'package:flutter/material.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';
import 'package:eoreporter_v1/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    try {
      // Check if user is already logged in
      final isLoggedIn = await _authService.isLoggedIn();
      
      if (isLoggedIn) {
        // Check if the current user's role is allowed
        final isRoleAllowed = await _authService.isUserRoleAllowed();
        
        if (!isRoleAllowed) {
          // User has admin role, force logout and show error
          await _authService.logout();
          if (mounted) {
            await _showRoleErrorAndNavigateToLogin();
          }
          return;
        }
        
        // User role is allowed, navigate to home
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // User not logged in, navigate to login
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } catch (e) {
      // Error occurred, navigate to login
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
    }
  }

  Future<void> _showRoleErrorAndNavigateToLogin() async {
    // Show error dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text(
          'This mobile app is only available for users with USER role. Admins should use the web application.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppConstants.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Icon(
              Icons.flash_on,
              size: 100,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            // App Name
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 40),
            // Loading Indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
} 