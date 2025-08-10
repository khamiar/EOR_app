import 'package:flutter/material.dart';

class AppConstants {
  // API Configuration
  static const String apiBaseUrl = 'http://192.168.1.3:8080/api';
  // static const String apiBaseUrl = 'http://localhost:8080/api';
  static const String baseUrl = 'http://192.168.1.3:8080';
  // static const String baseUrl = 'http://localhost:8080';
  
  // App Configuration
  static const String appName = 'EOReporter';
  static const String appVersion = '1.0.0';
  
  // Storage Keys
  static const String tokenKey = 'jwt_token';
  static const String userKey = 'user_data';
  
  // API Endpoints
  static const String loginEndpoint = '/auth/authenticate';
  static const String registerEndpoint = '/auth/register';
  static const String logoutEndpoint = '/auth/logout';
  static const String profileEndpoint = '/auth/profile';
  static const String outagesEndpoint = '/outages';
  static const String notificationsEndpoint = '/notifications';
  static const String feedbackEndpoint = '/feedback';
  static const String announcementsEndpoint = '/announcements';
  
  // Error Messages
  static const String networkError = 'Network error. Please check your internet connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String authError = 'Authentication failed. Please login again.';
  static const String unknownError = 'An unknown error occurred. Please try again.';
  
// Colors Themes
static const Color primaryColor = Color.fromRGBO(116, 32, 11, 1);    // Burnt Sienna / Rust Red
static const Color accentColor = Color.fromRGBO(113, 44, 33, 1);     // Redwood / Dark Coral
static const Color backgroundColor = Color(0xFFF5F5F5);               // White Smoke (light gray)
static const Color textColor = Color(0xFF212121);                     // Almost Black (dark gray)
static const Color errorColor = Color(0xFFD32F2F);                    // Persian Red
  
  // Text Styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textColor,
  );
  
  static const TextStyle subHeadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textColor,
  );
  
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: textColor,
  );
  
  // Spacing
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
} 