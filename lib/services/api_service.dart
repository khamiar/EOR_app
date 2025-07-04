import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

class ApiService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Helper method to clear all stored tokens
  Future<void> _clearAllTokens() async {
    try {
      await _storage.delete(key: AppConstants.tokenKey);
      await _storage.delete(key: 'token');
      await _storage.delete(key: 'jwt_token');
      await _storage.delete(key: AppConstants.userKey);
      await _storage.delete(key: 'user');
      print('🧹 All tokens cleared from storage');
    } catch (e) {
      print('Error clearing tokens: $e');
    }
  }
  
  ApiService() {
    _dio.options.baseUrl = AppConstants.apiBaseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 3);
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Don't add token to login/register requests
        final isAuthEndpoint = options.path.contains('/auth/authenticate') || 
                               options.path.contains('/auth/register');
        
        if (!isAuthEndpoint) {
          final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Handle token expiration
          print('🔓 Token expired or unauthorized - clearing stored tokens');
          await _clearAllTokens();
        }
        return handler.next(e);
      },
    ));
  }

  // Check if app is in offline mode
  Future<bool> _isOfflineMode() async {
    final offlineMode = await _storage.read(key: 'offline_mode');
    return offlineMode == 'true';
  }

  // Throw offline error for features that require backend
  void _throwOfflineError(String feature) {
    throw Exception('$feature is not available in offline mode. Please connect to internet and login again.');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Clear any existing expired tokens before login attempt
      await _clearAllTokens();
      
      final response = await _dio.post(AppConstants.loginEndpoint, data: {
        'email': email,
        'password': password,
      });
      
      if (response.statusCode == 200) {
        final token = response.data['token'];
        await _storage.write(key: AppConstants.tokenKey, value: token);
        return response.data;
      }
      throw Exception('Login failed: ${response.data['message'] ?? AppConstants.unknownError}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      throw Exception('Login failed: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> register(String fullName, String email, String password, String phoneNumber, String address, String role) async {
    try {
      final response = await _dio.post(AppConstants.registerEndpoint, data: {
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'address': address,
        'password': password,
        'role': role,
      });
      
      if (response.statusCode == 201) {
        final token = response.data['token'];
        await _storage.write(key: AppConstants.tokenKey, value: token);
        return response.data;
      }
      throw Exception('Registration failed: ${response.data['message'] ?? AppConstants.unknownError}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      throw Exception('Registration failed: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(AppConstants.logoutEndpoint);
    } catch (e) {
      // Continue with local logout even if server logout fails
      print('Server logout failed, continuing with local logout: $e');
    } finally {
      // Always clear local tokens
      await _clearAllTokens();
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    if (await _isOfflineMode()) {
      _throwOfflineError('Profile data');
    }
    
    try {
      final response = await _dio.get(AppConstants.profileEndpoint);
      return response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      throw Exception('Failed to get profile: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to get profile: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> submitOutageReport({
    required String title,
    required String description,
    required String location,
    required double latitude,
    required double longitude,
    String? imagePath,
    String? videoPath,
  }) async {
    if (await _isOfflineMode()) {
      _throwOfflineError('Outage reporting');
    }
    
    try {
      // Create the report data with proper types
      final reportData = {
        'title': title,
        'description': description,
        'manualLocation': location,
        'latitude': latitude.toString(), // Convert to string for JSON
        'longitude': longitude.toString(), // Convert to string for JSON
        'status': 'PENDING', // Add default status
        'reportedAt': DateTime.now().toIso8601String(), // Add report date
      };

      // Create form data
      FormData formData = FormData.fromMap({
        'report': jsonEncode(reportData), // Encode report data as JSON string
      });

      // Add media file if available
      if (imagePath != null) {
        formData.files.add(MapEntry(
          'media',
          await MultipartFile.fromFile(
            imagePath,
            contentType: MediaType('image', 'jpeg'),
          ),
        ));
      } else if (videoPath != null) {
        formData.files.add(MapEntry(
          'media',
          await MultipartFile.fromFile(
            videoPath,
            contentType: MediaType('video', 'mp4'),
          ),
        ));
      }

      final response = await _dio.post(AppConstants.outagesEndpoint, data: formData);
      return response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      throw Exception('Failed to submit report: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to submit report: ${e.toString()}');
    }
  }

  Future<List<dynamic>> getMyReports() async {
    if (await _isOfflineMode()) {
      _throwOfflineError('Reports data');
    }
    
    try {
      final response = await _dio.get('${AppConstants.outagesEndpoint}/my');
      return response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      throw Exception('Failed to get reports: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to get reports: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getReportDetails(String reportId) async {
    if (await _isOfflineMode()) {
      _throwOfflineError('Report details');
    }
    
    try {
      final response = await _dio.get('${AppConstants.outagesEndpoint}/$reportId');
      return response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      throw Exception('Failed to get report details: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to get report details: ${e.toString()}');
    }
  }

  Future<List<dynamic>> getNotifications() async {
    if (await _isOfflineMode()) {
      _throwOfflineError('Notifications');
    }
    
    try {
      final response = await _dio.get(AppConstants.notificationsEndpoint);
      return response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      throw Exception('Failed to get notifications: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to get notifications: ${e.toString()}');
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    if (await _isOfflineMode()) {
      _throwOfflineError('Notification updates');
    }
    
    try {
      await _dio.put('${AppConstants.notificationsEndpoint}/$notificationId/read');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      throw Exception('Failed to mark notification as read: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to mark notification as read: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> submitFeedback({
    required String subject,
    required String message,
  }) async {
    if (await _isOfflineMode()) {
      _throwOfflineError('Feedback submission');
    }
    
    try {
      final response = await _dio.post(AppConstants.feedbackEndpoint, data: {
        'subject': subject,
        'message': message,
      });
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Ensure we return a proper Map<String, dynamic>
        if (response.data is Map<String, dynamic>) {
          return response.data;
        } else {
          // If response.data is not the expected type, create a safe response
          return {
            'message': 'Feedback submitted successfully',
            'id': null,
            'status': 'PENDING',
            'createdAt': DateTime.now().toIso8601String(),
          };
        }
      }
      
      // Handle error response
      String errorMessage = AppConstants.unknownError;
      if (response.data is Map<String, dynamic> && response.data.containsKey('error')) {
        errorMessage = response.data['error'].toString();
      }
      throw Exception('Failed to submit feedback: $errorMessage');
      
    } on DioException catch (e) {
      
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      
      // Handle specific error messages from backend
      if (e.response?.statusCode == 400) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData.containsKey('error')) {
          throw Exception(errorData['error'].toString());
        }
      }
      
      String errorMessage = e.message ?? 'Unknown network error';
      if (e.response?.data is Map<String, dynamic> && 
          e.response!.data.containsKey('error')) {
        errorMessage = e.response!.data['error'].toString();
      }
      
      throw Exception('Failed to submit feedback: $errorMessage');
    } catch (e) {
      throw Exception('Failed to submit feedback: ${e.toString()}');
    }
  }

  Future<List<dynamic>> getMyFeedback() async {
    if (await _isOfflineMode()) {
      _throwOfflineError('Feedback history');
    }
    
    try {
      final response = await _dio.get('${AppConstants.feedbackEndpoint}/my');
      
      if (response.data is List) {
        return response.data;
      } else if (response.data is Map<String, dynamic> && response.data.containsKey('data')) {
        // In case the response is wrapped in a data field
        return response.data['data'] is List ? response.data['data'] : [];
      } else {
        return [];
      }
    } on DioException catch (e) {
      
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      
      String errorMessage = e.message ?? 'Unknown error';
      if (e.response?.data is Map<String, dynamic> && 
          e.response!.data.containsKey('error')) {
        errorMessage = e.response!.data['error'].toString();
      }
      
      throw Exception('Failed to get feedback: $errorMessage');
    } catch (e) {
      throw Exception('Failed to get feedback: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getFeedbackById(String feedbackId) async {
    if (await _isOfflineMode()) {
      _throwOfflineError('Feedback details');
    }
    
    try {
      final response = await _dio.get('${AppConstants.feedbackEndpoint}/$feedbackId');
      return response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      throw Exception('Failed to get feedback details: ${e.response?.data['error'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to get feedback details: ${e.toString()}');
    }
  }
} 