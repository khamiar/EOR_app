import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

class ApiService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  ApiService() {
    _dio.options.baseUrl = AppConstants.apiBaseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 3);
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        if (e.response?.statusCode == 401) {
          // Handle token expiration
          _storage.delete(key: AppConstants.tokenKey);
        }
        return handler.next(e);
      },
    ));
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
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
      await _storage.delete(key: AppConstants.tokenKey);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(AppConstants.networkError);
      }
      throw Exception('Logout failed: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Logout failed: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
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
    try {
      // Create the report data with proper types
      final reportData = {
        'title': title,
        'description': description,
        'manualLocation': location,
        'latitude': latitude.toString(), // Convert to string for JSON
        'longitude': longitude.toString(), // Convert to string for JSON
        'status': 'PENDING', // Add default status
        'reportDate': DateTime.now().toIso8601String(), // Add report date
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
} 