import 'package:flutter/material.dart';
import 'package:eoreporter_v1/services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        _user = await _apiService.getProfile();
        _isAuthenticated = true;
        notifyListeners();
      } catch (e) {
        await _storage.delete(key: 'jwt_token');
        _isAuthenticated = false;
        _user = null;
        notifyListeners();
      }
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiService.login(email, password);
      _user = response['user'];
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register(String fullName, String email, String password, String phoneNumber, String address, String role) async {
    try {
      final response = await _apiService.register(fullName, email, password, phoneNumber, address, role);
      _user = response['user'];
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.logout();
      _isAuthenticated = false;
      _user = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
} 