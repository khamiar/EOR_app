import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class NotificationModel {
  final int id;
  final String title;
  final String body;
  bool read;

  NotificationModel({required this.id, required this.title, required this.body, required this.read});

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
    id: json['id'],
    title: json['title'],
    body: json['body'],
    read: json['read'],
  );
}

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
      developer.log('All tokens cleared from storage', name: 'ApiService');
    } catch (e) {
              developer.log('Error clearing tokens: $e', name: 'ApiService');
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
    required String region,
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
        'title': title, // <-- This will now be the selected category
        'region': region,
        'description': description,
        'manualLocation': location,
        'latitude': latitude.toString(), 
        'longitude': longitude.toString(), 
        'status': 'PENDING', 
        'reportedAt': DateTime.now().toIso8601String(), 
      };

      // Create form data
      FormData formData = FormData.fromMap({
        'report': jsonEncode(reportData), 
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

  Future<List<Map<String, dynamic>>> fetchMyReports() async {
    try {
      // Check if user has valid token
      final token = await _storage.read(key: AppConstants.tokenKey);
      print('DEBUG: Token from storage: ${token != null ? "Token exists (length: ${token.length})" : "No token found"}');
      
      if (token == null) {
        throw Exception('No authentication token found. Please login again.');
      }
      
      print('DEBUG: Making request to ${AppConstants.outagesEndpoint}/my');
      final response = await _dio.get(
        '${AppConstants.outagesEndpoint}/my',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response data type: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        final List data = response.data;
        print('DEBUG: Found ${data.length} reports');
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load reports: HTTP ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('DEBUG: DioException occurred');
      print('DEBUG: Error type: ${e.type}');
      print('DEBUG: Response status: ${e.response?.statusCode}');
      print('DEBUG: Response data: ${e.response?.data}');
      
      if (e.response?.statusCode == 401) {
        // Token expired or invalid
        await _clearAllTokens();
        throw Exception('Session expired. Please login again.');
      } else if (e.type == DioExceptionType.connectionTimeout || 
                 e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      } else if (e.response?.statusCode == 404) {
        throw Exception('Reports endpoint not found. Please contact support.');
      }
      throw Exception('Error fetching reports: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      print('DEBUG: General exception: $e');
      throw Exception('Unexpected error: ${e.toString()}');
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

  static Future<int> fetchUnreadCount() async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.tokenKey);
      
      if (token == null) {
        return 0; // No token means no authenticated user
      }
      
      final dio = Dio();
      dio.options.baseUrl = AppConstants.apiBaseUrl;
      
      final response = await dio.get(
        '${AppConstants.notificationsEndpoint}/unread/count',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.statusCode == 200) {
        // Backend returns Long as JSON number, not string
        if (response.data is int) {
          return response.data;
        } else if (response.data is String) {
          return int.tryParse(response.data) ?? 0;
        } else {
          // If response is Map with count key
          if (response.data is Map && response.data.containsKey('count')) {
            return response.data['count'] ?? 0;
          }
          // Try parsing as string if it's a number
          return int.tryParse(response.data.toString()) ?? 0;
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching unread count: $e');
      
      // Fallback: Count unread notifications locally
      try {
        return await _fallbackUnreadCount();
      } catch (fallbackError) {
        print('Fallback count also failed: $fallbackError');
        return 0;
      }
    }
  }

  // Fallback method to count unread notifications locally
  static Future<int> _fallbackUnreadCount() async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.tokenKey);
      
      if (token == null) return 0;
      
      final dio = Dio();
      dio.options.baseUrl = AppConstants.apiBaseUrl;
      
      final response = await dio.get(
        AppConstants.notificationsEndpoint,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.statusCode == 200 && response.data is List) {
        final notifications = response.data as List;
        int unreadCount = 0;
        
        for (var notification in notifications) {
          if (notification is Map<String, dynamic>) {
            final isRead = notification['read'] ?? notification['isRead'] ?? false;
            if (!isRead) {
              unreadCount++;
            }
          }
        }
        
        print('Fallback count: Found $unreadCount unread notifications');
        return unreadCount;
      }
      
      return 0;
    } catch (e) {
      print('Fallback count error: $e');
      return 0;
    }
  }

  Future<bool> deleteNotification(int id) async {
    try {
      final response = await _dio.delete('/notifications/$id');
      return response.statusCode == 200;
    } catch (e) {
      // Optionally log error
      return false;
    }
  }

  Future<List<dynamic>> getAnnouncements() async {
    if (await _isOfflineMode()) {
      _throwOfflineError('Announcements');
    }

    try {
      final response = await _dio.get(AppConstants.announcementsEndpoint);
      if (response.statusCode == 200) {
        final List data = response.data;
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get announcements: HTTP ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _clearAllTokens();
        throw Exception('Session expired. Please login again.');
      } else if (e.type == DioExceptionType.connectionTimeout || 
                 e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      } 
      throw Exception('Failed to get announcements: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }
}