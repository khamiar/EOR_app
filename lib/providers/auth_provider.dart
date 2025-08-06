import 'package:flutter/material.dart';
import 'package:eoreporter_v1/services/api_service.dart';
import 'package:eoreporter_v1/services/auth_service.dart';
import 'package:eoreporter_v1/services/auth_checker_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  String? _authToken;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;
  String? get authToken => _authToken;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      print('AUTH: Checking authentication status...');
      // Use AuthCheckerService for consistent authentication checking
      final isAuth = await AuthCheckerService.isAuthenticated();
      final token = await AuthCheckerService.getToken();
      
      print('AUTH: isAuth: $isAuth, token: ${token != null ? 'exists' : 'null'}');
      
      if (isAuth && token != null) {
        _authToken = token;
        
        // Try to get user profile
        try {
          print('AUTH: Getting user profile...');
          final user = await _authService.getCurrentUser();
          if (user != null) {
            _user = user.toJson();
            _isAuthenticated = true;
            print('AUTH: User authenticated successfully: ${user.email}');
          } else {
            print('AUTH: No user data found');
            _isAuthenticated = false;
            _authToken = null;
            _user = null;
            await AuthCheckerService.clearAuthData();
          }
        } catch (e) {
          print('AUTH: Failed to get profile, treating as unauthenticated: $e');
          _isAuthenticated = false;
          _authToken = null;
          _user = null;
          await AuthCheckerService.clearAuthData();
        }
      } else {
        print('AUTH: No valid authentication found');
        _isAuthenticated = false;
        _authToken = null;
        _user = null;
      }
      
      notifyListeners();
    } catch (e) {
      print('AUTH: Error checking auth status: $e');
      _isAuthenticated = false;
      _authToken = null;
      _user = null;
      notifyListeners();
    }
  }

  /// Refresh authentication status manually
  Future<void> refreshAuthStatus() async {
    await _checkAuthStatus();
  }

  Future<void> login(String email, String password) async {
    try {
      print('AUTH_PROVIDER: Logging in...');
      final user = await _authService.login(email, password);
      if (user != null) {
        _user = user.toJson();
        _authToken = user.token;
        _isAuthenticated = true;
        print('AUTH_PROVIDER: Login successful: ${user.email}');
      } else {
        print('AUTH_PROVIDER: Login failed - no user returned');
        throw Exception('Login failed - no user data received');
      }

      notifyListeners();
    } catch (e) {
      print('AUTH_PROVIDER: Login error: $e');
      rethrow;
    }
  }

  Future<void> register(String fullName, String email, String password, String phoneNumber, String address, String role) async {
    try {
      print('AUTH_PROVIDER: Registering...');
      await _authService.register(fullName, email, password, phoneNumber, address, role);
      
      // After successful registration, get the user data
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _user = user.toJson();
        _authToken = user.token;
        _isAuthenticated = true;
        print('AUTH_PROVIDER: Registration successful: ${user.email}');
      } else {
        print('AUTH_PROVIDER: Registration failed - no user data found');
        throw Exception('Registration failed - no user data found');
      }

      notifyListeners();
    } catch (e) {
      print('AUTH_PROVIDER: Registration error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      print('AUTH_PROVIDER: Logging out...');
      await _authService.logout();
      
      _authToken = null;
      _user = null;
      _isAuthenticated = false;

      print('AUTH_PROVIDER: Logout successful');
      notifyListeners();
    } catch (e) {
      print('AUTH_PROVIDER: Logout error: $e');
      // Even if server logout fails, clear local data
      _authToken = null;
      _user = null;
      _isAuthenticated = false;
      notifyListeners();
    }
  }
} 
