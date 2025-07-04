import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../constants/app_constants.dart';
import 'user_history_service.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  final _userHistoryService = UserHistoryService();

  String _getUserFriendlyError(dynamic error) {
    if (error is FormatException) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }
    
    if (error.toString().contains('Connection refused')) {
      return 'Unable to connect to the server. Please make sure the server is running and try again.';
    }
    
    if (error.toString().contains('SocketException')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    
    if (error.toString().contains('timeout')) {
      return 'Connection timed out. Please try again.';
    }

    if (error.toString().contains('403')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    }
    
    // Default error message
    return 'An error occurred. Please try again.';
  }

  Future<User?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/auth/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // print('=== LOGIN DEBUG INFO ===');
        // print('Full response data: $data');
        // print('Token: ${data['token']}');
        // print('Role from response: ${data['role']}');
        // print('User object: ${data['user']}');
        // print('========================');
        
        // Create user data with the available information
        // Backend returns role as enum (USER, ADMIN), convert to string
        String? userRole = data['role']?.toString() ?? 'USER';
        
        final userData = {
          'email': data['email'] ?? email,
          'token': data['token'],
          'role': userRole,
          'fullName': data['fullName'],
          'phoneNumber': data['phoneNumber'],
          'address': data['address'],
          'id': data['id']?.toString(),
        };
        
        // print('=== USER DATA DEBUG ===');
        // print('Created userData: $userData');
        // print('=======================');
        
        final user = User.fromJson(userData);
        
        // print('=== USER OBJECT DEBUG ===');
        // print('User role: ${user.role}');
        // print('User role uppercase: ${user.role?.toUpperCase()}');
        // print('Role check result: ${user.role != null && user.role!.toUpperCase() != 'USER'}');
        // print('========================');
        
        // Check if user role is allowed for mobile app
        if (user.role != null && user.role!.toUpperCase() != 'USER') {
          await _clearAllCachedData(); // Clear any cached data for security
          throw Exception('Access denied. Invalid USER credentials. Register as user first');
        }
        
        // Store token securely
        await _storage.write(key: AppConstants.tokenKey, value: user.token);
        await _storage.write(key: AppConstants.userKey, value: jsonEncode(user.toJson()));
        
        // Store credentials for offline login (encrypted)
        await _storage.write(key: 'cached_email', value: email);
        await _storage.write(key: 'cached_password', value: password);
        await _storage.write(key: 'cached_role', value: user.role ?? 'USER');
        await _storage.write(key: 'offline_mode', value: 'false');
        
        // Save user login to history
        await _userHistoryService.saveUserLogin(user);
        
        return user;
      } else if (response.statusCode == 403) {
        throw Exception('Invalid email or password. Please check your credentials and try again.');
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Login failed. Please try again.';
          throw Exception(errorMessage);
        } catch (e) {
          throw Exception('Login failed. Please try again.');
        }
      }
    } catch (e) {
      print('Login error: $e');
      
      // Try offline login if server is unreachable
      if (_isNetworkError(e)) {
        print('Network error detected, attempting offline login...');
        return await _attemptOfflineLogin(email, password);
      }
      
      if (e is Exception) {
        rethrow; // Re-throw if it's already a user-friendly message
      }
      throw Exception(_getUserFriendlyError(e));
    }
  }

  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('connection refused') ||
           errorString.contains('socketexception') ||
           errorString.contains('timeout') ||
           errorString.contains('network') ||
           errorString.contains('connection timed out') ||
           errorString.contains('connection reset') ||
           errorString.contains('no route to host');
  }

  Future<User?> _attemptOfflineLogin(String email, String password) async {
    try {
      final cachedEmail = await _storage.read(key: 'cached_email');
      final cachedPassword = await _storage.read(key: 'cached_password');
      final cachedRole = await _storage.read(key: 'cached_role');
      
      if (cachedEmail == email && cachedPassword == password) {
        // Check if cached user role is allowed for mobile app
        if (cachedRole != null && cachedRole.toUpperCase() != 'USER') {
          await _clearAllCachedData(); // Clear any cached data for security
          throw Exception('Access denied. Invalid USER credentials. Register as user first');
        }
        
        // Create offline user data
        final userData = {
          'email': email,
          'token': 'offline_token_${DateTime.now().millisecondsSinceEpoch}',
          'role': cachedRole ?? 'USER',
        };
        
        final user = User.fromJson(userData);
        
        // Store offline mode flag
        await _storage.write(key: AppConstants.tokenKey, value: user.token);
        await _storage.write(key: AppConstants.userKey, value: jsonEncode(user.toJson()));
        await _storage.write(key: 'offline_mode', value: 'true');
        
        // Save user login to history
        await _userHistoryService.saveUserLogin(user);
        
        print('Offline login successful for: $email');
        return user;
      } else {
        throw Exception('No cached credentials found or credentials don\'t match. Please connect to internet for first-time login.');
      }
    } catch (e) {
      print('Offline login failed: $e');
      throw Exception('Offline login failed. Please connect to internet or check your credentials.');
    }
  }

  Future<void> register(String fullName, String email, String password, String phoneNumber, String address, String role) async {
    try {
      // Ensure role is always "USER"
      final userRole = role.toUpperCase() == "USER" ? "USER" : "USER";
      
      print('Attempting to register with data: ${jsonEncode({
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'address': address,
        'password': password,
        'role': userRole,
      })}');

      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'phoneNumber': phoneNumber,
          'address': address,
          'password': password,
          'role': userRole,
        }),
      );

      print('Registration response status: ${response.statusCode}');
      print('Registration response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          // Create a basic user object with the available data
          final userData = {
            'email': email,
            'fullName': fullName,
            'phoneNumber': phoneNumber,
            'address': address,
            'role': userRole,
            'token': data['token']
          };
          
          final newUser = User.fromJson(userData);
          
          // Check if user role is allowed for mobile app
          if (newUser.role != null && newUser.role!.toUpperCase() != 'USER') {
            await _clearAllCachedData(); // Clear any cached data for security
            throw Exception('Access denied. This mobile app is only available for users with USER role. Admins should use the web application.');
          }
          
          // Store the token
          await _storage.write(key: AppConstants.tokenKey, value: data['token']);
          
          // Store the user data
          await _storage.write(key: AppConstants.userKey, value: jsonEncode(userData));
          
          // Store credentials for offline login (encrypted)
          await _storage.write(key: 'cached_email', value: email);
          await _storage.write(key: 'cached_role', value: newUser.role ?? 'USER');
          
          // Save user registration to history
          await _userHistoryService.saveUserLogin(newUser);
        }
        return;
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Registration failed. Please try again.';
          throw Exception(errorMessage);
        } catch (e) {
          throw Exception('Registration failed. Please try again.');
        }
      }
    } catch (e) {
      print('Registration error: $e');
      throw Exception(_getUserFriendlyError(e));
    }
  }

  Future<void> logout() async {
    await _clearAllCachedData();
  }

  Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }

  Future<User?> getCurrentUser() async {
    final userJson = await _storage.read(key: AppConstants.userKey);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<bool> isOfflineMode() async {
    final offlineMode = await _storage.read(key: 'offline_mode');
    return offlineMode == 'true';
  }

  Future<String?> getCurrentUserRole() async {
    final user = await getCurrentUser();
    return user?.role;
  }

  Future<bool> isUserRoleAllowed() async {
    final role = await getCurrentUserRole();
    return role == null || role.toUpperCase() == 'USER';
  }

  Future<void> _clearAllCachedData() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.userKey);
    await _storage.delete(key: 'cached_email');
    await _storage.delete(key: 'cached_password');
    await _storage.delete(key: 'cached_role');
    await _storage.delete(key: 'offline_mode');
  }

  // User History Service methods
  UserHistoryService get userHistoryService => _userHistoryService;

  Future<List<String>> getFrequentEmails({int limit = 5}) async {
    return await _userHistoryService.getFrequentEmails(limit: limit);
  }

  Future<String?> getLastLoggedInUserEmail() async {
    return await _userHistoryService.getLastLoggedInUserEmail();
  }

  Future<void> clearLoginHistory() async {
    await _userHistoryService.clearLoginHistory();
  }
}