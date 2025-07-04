import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_history_model.dart';
import '../models/user.dart';

class UserHistoryService {
  static const String _loginHistoryKey = 'login_history';
  static const String _lastLoggedInUserKey = 'last_logged_in_user';
  static const int _maxHistoryEntries = 10; // Keep only last 10 login entries

  /// Save user login to history
  Future<void> saveUserLogin(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create new login history entry
      final newEntry = LoginHistoryEntry(
        email: user.email,
        fullName: user.fullName,
        loginTime: DateTime.now(),
      );

      // Get existing history
      final existingHistory = await getLoginHistory();
      
      // Remove duplicate entry if exists (same email)
      existingHistory.removeWhere((entry) => entry.email == user.email);
      
      // Add new entry at the beginning
      existingHistory.insert(0, newEntry);
      
      // Keep only the last N entries
      if (existingHistory.length > _maxHistoryEntries) {
        existingHistory.removeRange(_maxHistoryEntries, existingHistory.length);
      }
      
      // Save updated history
      final historyJson = existingHistory.map((entry) => entry.toJson()).toList();
      await prefs.setString(_loginHistoryKey, jsonEncode(historyJson));
      
      // Save last logged in user
      await prefs.setString(_lastLoggedInUserKey, user.email);
      
    } catch (e) {
      print('Error saving user login history: $e');
    }
  }

  /// Get login history list
  Future<List<LoginHistoryEntry>> getLoginHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_loginHistoryKey);
      
      if (historyString == null) return [];
      
      final List<dynamic> historyJson = jsonDecode(historyString);
      return historyJson
          .map((json) => LoginHistoryEntry.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting login history: $e');
      return [];
    }
  }

  /// Get last logged in user email
  Future<String?> getLastLoggedInUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastLoggedInUserKey);
    } catch (e) {
      print('Error getting last logged in user: $e');
      return null;
    }
  }

  /// Remove specific user from history
  Future<void> removeUserFromHistory(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingHistory = await getLoginHistory();
      
      existingHistory.removeWhere((entry) => entry.email == email);
      
      final historyJson = existingHistory.map((entry) => entry.toJson()).toList();
      await prefs.setString(_loginHistoryKey, jsonEncode(historyJson));
      
      // If removed user was the last logged in user, clear that too
      final lastLoggedInUser = await getLastLoggedInUserEmail();
      if (lastLoggedInUser == email) {
        await prefs.remove(_lastLoggedInUserKey);
      }
      
    } catch (e) {
      print('Error removing user from history: $e');
    }
  }

  /// Clear all login history
  Future<void> clearLoginHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_loginHistoryKey);
      await prefs.remove(_lastLoggedInUserKey);
    } catch (e) {
      print('Error clearing login history: $e');
    }
  }

  /// Check if user exists in history
  Future<bool> userExistsInHistory(String email) async {
    try {
      final history = await getLoginHistory();
      return history.any((entry) => entry.email == email);
    } catch (e) {
      print('Error checking user in history: $e');
      return false;
    }
  }

  /// Get user's last login time
  Future<DateTime?> getUserLastLoginTime(String email) async {
    try {
      final history = await getLoginHistory();
      final userEntry = history.firstWhere(
        (entry) => entry.email == email,
        orElse: () => LoginHistoryEntry(email: '', loginTime: DateTime.now()),
      );
      
      return userEntry.email.isNotEmpty ? userEntry.loginTime : null;
    } catch (e) {
      print('Error getting user last login time: $e');
      return null;
    }
  }

  /// Get frequently used emails (for autocomplete)
  Future<List<String>> getFrequentEmails({int limit = 5}) async {
    try {
      final history = await getLoginHistory();
      return history
          .take(limit)
          .map((entry) => entry.email)
          .toList();
    } catch (e) {
      print('Error getting frequent emails: $e');
      return [];
    }
  }
} 