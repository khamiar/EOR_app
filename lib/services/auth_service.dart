import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../constants/app_constants.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();

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
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Create user data with the available information
        final userData = {
          'email': email,
          'token': data['token'],
        };
        
        final user = User.fromJson(userData);
        
        // Store token securely
        await _storage.write(key: 'token', value: user.token);
        await _storage.write(key: 'user', value: jsonEncode(user.toJson()));
        
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
      if (e is Exception) {
        rethrow; // Re-throw if it's already a user-friendly message
      }
      throw Exception(_getUserFriendlyError(e));
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
          // Store the token
          await _storage.write(key: 'token', value: data['token']);
          
          // Create a basic user object with the available data
          final userData = {
            'email': email,
            'fullName': fullName,
            'phoneNumber': phoneNumber,
            'address': address,
            'role': userRole,
            'token': data['token']
          };
          
          // Store the user data
          await _storage.write(key: 'user', value: jsonEncode(userData));
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
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<User?> getCurrentUser() async {
    final userJson = await _storage.read(key: 'user');
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}