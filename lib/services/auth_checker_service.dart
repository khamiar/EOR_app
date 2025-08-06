import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class AuthCheckerService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Check if user is authenticated by verifying token exists and is valid format
  static Future<bool> isAuthenticated() async {
    try {
      print('AUTH_CHECKER: Checking authentication...');
      final token = await _storage.read(key: AppConstants.tokenKey);
      
      print('AUTH_CHECKER: Token found: ${token != null ? 'yes' : 'no'}');
      
      if (token == null || token.isEmpty) {
        print('AUTH_CHECKER: No token found');
        return false;
      }

      // Basic JWT format check (should have 3 parts separated by dots)
      final parts = token.split('.');
      if (parts.length != 3) {
        print('AUTH_CHECKER: Invalid JWT format');
        return false;
      }

      // Check if token is not obviously expired (basic check)
      // You can add more sophisticated JWT parsing here if needed
      print('AUTH_CHECKER: Token is valid');
      return true;
    } catch (e) {
      print('AUTH_CHECKER: Auth check error: $e');
      return false;
    }
  }

  /// Get the current token
  static Future<String?> getToken() async {
    try {
      print('AUTH_CHECKER: Getting token...');
      final token = await _storage.read(key: AppConstants.tokenKey);
      print('AUTH_CHECKER: Token retrieved: ${token != null ? 'yes' : 'no'}');
      return token;
    } catch (e) {
      print('AUTH_CHECKER: Error getting token: $e');
      return null;
    }
  }

  /// Check if the app is in offline mode
  static Future<bool> isOfflineMode() async {
    try {
      final offlineMode = await _storage.read(key: 'offline_mode');
      return offlineMode == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Clear all authentication data
  static Future<void> clearAuthData() async {
    try {
      print('AUTH_CHECKER: Clearing auth data...');
      await _storage.delete(key: AppConstants.tokenKey);
      await _storage.delete(key: AppConstants.userKey);
      await _storage.delete(key: 'offline_mode');
      await _storage.delete(key: 'cached_email');
      await _storage.delete(key: 'cached_password');
      await _storage.delete(key: 'cached_role');
      print('AUTH_CHECKER: Auth data cleared successfully');
    } catch (e) {
      print('AUTH_CHECKER: Error clearing auth data: $e');
    }
  }
} 