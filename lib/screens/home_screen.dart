import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';
import 'package:eoreporter_v1/widgets/custom_app_bar.dart';
import 'package:eoreporter_v1/screens/my_reports_screen.dart';
import 'package:eoreporter_v1/screens/feedback_screen.dart';
import 'package:eoreporter_v1/screens/notifications_screen.dart';
import 'package:eoreporter_v1/utils/animations.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:external_path/external_path.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final List<Widget> _screens;
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadedFiles = {};
  Directory? _downloadDirectory;
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isLoadingAnnouncements = false;
  String? _announcementError;
  List<Map<String, dynamic>> announcements = [];
  
  // Notification count state
  int _unreadNotificationCount = 0;
  Timer? _notificationCountTimer;
  Timer? _announcementsRefreshTimer;

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoadingAnnouncements = true;
      _announcementError = null;
    });
        try {
      final apiAnnouncements = await ApiService().getAnnouncements();
      setState(() {
        announcements = apiAnnouncements.map((announcement) => {
          'id': announcement['id'],
          'title': announcement['title'],
          'content': announcement['content'], // Use consistent field name
          'description': announcement['content'], // Keep for backward compatibility
          'date': DateTime.parse(announcement['createdAt'] ?? announcement['publishDate']),
          'type': _mapCategoryToType(announcement['category']),
          'attachment': announcement['attachmentUrl'] != null ? {
            'url': _buildFullUrl(announcement['attachmentUrl']),
            'name': announcement['attachmentUrl']?.split('/').last ?? 'attachment',
            'type': _getFileType(announcement['attachmentUrl'])
          } : null,
        }).toList();
        _isLoadingAnnouncements = false;
      });
    } catch (e) {
      setState(() {
        _announcementError = e.toString();
        _isLoadingAnnouncements = false;
      });
    }
  }

    String _mapCategoryToType(String? category) {
    switch (category?.toLowerCase()) {
      case 'maintenance': return 'maintenance';
      case 'emergency': return 'emergency';
      default: return 'announcement';
    }
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      const MyReportsScreen(),
      const FeedbackScreen(),
      const NotificationsScreen(),
    ];
    _initializeDio();
    _initializeDownloadDirectory();
    _loadAnnouncements();
    _startAnnouncementsRefreshTimer();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notificationCountTimer?.cancel();
    _announcementsRefreshTimer?.cancel();
    super.dispose();
  }

  void _initializeDio() {
    _dio = Dio();
    _dio.options.baseUrl = AppConstants.apiBaseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 3);
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add authentication token to all requests
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<void> _initializeDownloadDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();

      final downloadPath = Platform.isWindows 
          ? '${appDir.path}\\EO Reporter Downloads'
          : '${appDir.path}/EO Reporter Downloads';

      _downloadDirectory = Directory(downloadPath);
      
      if (!await _downloadDirectory!.exists()) {
        await _downloadDirectory!.create(recursive: true);
      }

      await _checkExistingDownloads();
    } catch (e) {
      debugPrint('Error initializing download directory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing downloads: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to get file type from attachment URL
  String? _getFileType(String? url) {
    if (url == null) return null;
    if (url.toLowerCase().endsWith('.pdf')) return 'pdf';
    if (url.toLowerCase().contains('.jpg') || url.toLowerCase().contains('.png')) return 'image';
    return 'file';
  }

  // Method to build full URL for attachments
  String _buildFullUrl(String? relativeUrl) {
    if (relativeUrl == null) return '';
    
    // If it's already a full URL, return as is
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }
    
    // Remove leading slash if present
    final cleanUrl = relativeUrl.startsWith('/') ? relativeUrl.substring(1) : relativeUrl;
    
    // Extract base URL from apiBaseUrl (remove /api suffix)
    const baseUrl = AppConstants.baseUrl;
    
    // Build full URL using the base URL from constants
    // Files are stored in the uploads directory, so we need to include that in the path
    return '$baseUrl/uploads/$cleanUrl';
  }

  Future<void> _checkExistingDownloads() async {
    try {
      final files = await _downloadDirectory!.list().toList();
      for (var file in files) {
        if (file is File) {
          final fileName = file.path.split(Platform.pathSeparator).last;
          for (var announcement in announcements) {
            if (announcement['attachment'] != null &&
                announcement['attachment']['name'] == fileName) {
              _downloadedFiles[announcement['attachment']['url']] = file.path;
            }
          }
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error checking existing downloads: $e');
    }
  }

  // Notification count management methods
  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await ApiService.fetchUnreadCount();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (e) {
      print('Error loading notification count: $e');
      // Don't show error to user for this background operation
      // API fallback will handle the error gracefully
    }
  }

  void _startNotificationCountTimer() {
    // Update notification count every 30 seconds
    _notificationCountTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUnreadNotificationCount();
    });
  }

  void _startAnnouncementsRefreshTimer() {
    // Refresh announcements every 60 seconds
    _announcementsRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadAnnouncements();
    });
  }

  // Method to update count when user navigates to notifications
  void _updateNotificationCount() {
    _loadUnreadNotificationCount();
  }

  List<Map<String, dynamic>> get filteredAnnouncements {
    if (_searchQuery.isEmpty) return announcements;
    return announcements.where((announcement) {
      final title = announcement['title'].toString().toLowerCase();
      final description = announcement['description'].toString().toLowerCase();
      final date = DateFormat('MMM d, y').format(announcement['date']).toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || 
        description.contains(query) || 
        date.contains(query);
    }).toList();
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'maintenance':
        return Colors.orange;
      case 'emergency':
        return Colors.red;
      case 'announcement':
        return Colors.green;
      default:
        return AppConstants.primaryColor;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'maintenance':
        return Icons.engineering;
      case 'emergency':
        return Icons.warning_rounded;
      case 'announcement':
        return Icons.campaign;
      default:
        return Icons.info;
    }
  }

  Future<void> _downloadFileForViewing(Map<String, dynamic> attachment) async {
    // For viewing, we'll use the app's internal directory to avoid permission issues
    if (_downloadDirectory == null) {
      await _initializeDownloadDirectory();
    }

    final filePath = Platform.isWindows
        ? '${_downloadDirectory!.path}\\${attachment['name']}'
        : '${_downloadDirectory!.path}/${attachment['name']}';

    await _dio.download(
      attachment['url'],
      filePath,
      options: Options(
        receiveTimeout: const Duration(minutes: 2),
        sendTimeout: const Duration(minutes: 2),
      ),
    ).timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        throw TimeoutException('Download timed out');
      },
    );

    setState(() {
      _downloadedFiles[attachment['url']] = filePath;
    });
  }

  Future<void> _downloadFile(Map<String, dynamic> attachment) async {
    // Always download, don't check if already downloaded
    // If user wants to open downloaded file, they should use the view button

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission is required to download files'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Get the Downloads directory path
      String downloadPath;
      if (Platform.isAndroid) {
        downloadPath = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOWNLOADS);
      } else if (Platform.isIOS) {
        downloadPath = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOWNLOADS);
      } else {
        // For Windows, use the app's download directory
        if (_downloadDirectory == null) {
          await _initializeDownloadDirectory();
        }
        downloadPath = _downloadDirectory!.path;
      }

      final filePath = Platform.isWindows
          ? '$downloadPath\\${attachment['name']}'
          : '$downloadPath/${attachment['name']}';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading ${attachment['name']}...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await _dio.download(
        attachment['url'],
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress[attachment['url']] = received / total;
            });
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(minutes: 2),
        ),
      ).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException('Download timed out');
        },
      );

      setState(() {
        _downloadedFiles[attachment['url']] = filePath;
        _downloadProgress.remove(attachment['url']);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${attachment['name']} downloaded successfully'),
                      Text(
                        Platform.isAndroid ? 'Saved to Downloads folder' : 'Saved to device',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _openDownloadedFile(filePath, attachment['type']),
                  child: const Text(
                    'OPEN',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _downloadProgress.remove(attachment['url']);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () => _downloadFile(attachment),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openDownloadedFile(String filePath, String type) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        // For files saved to Downloads folder, try to open with external app
        if (Platform.isAndroid) {
          // Try to open with external app first
          try {
            final uri = Uri.file(filePath);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
              return;
            }
          } catch (e) {
            // If external app fails, fall back to in-app viewer
          }
          
          // Fall back to in-app viewer
          if (type == 'pdf') {
            _showPdfViewerFromPath(filePath, file.path.split('/').last);
          } else if (type == 'image') {
            _showImageViewerFromPath(filePath, file.path.split('/').last);
          } else {
            // For other file types, show a message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File saved to Downloads: ${file.path.split('/').last}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } else {
          // For other platforms, try to open with external app
          final uri = Uri.file(filePath);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            throw Exception('Could not open file');
          }
        }
      } else {
        throw Exception('File not found');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDownloadedFile(Map<String, dynamic> attachment) async {
    try {
      final filePath = _downloadedFiles[attachment['url']];
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          setState(() {
            _downloadedFiles.remove(attachment['url']);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${attachment['name']} deleted'),
                backgroundColor: Colors.grey[600],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// This function is used to display attachment options based on the provided map of attachments.
  /// 
  /// Args:
  ///   attachment (Map<String, dynamic>): The `_showAttachmentOptions` function takes a parameter
  /// `attachment` of type `Map<String, dynamic>`. This means that `attachment` is a map where the keys
  /// are of type `String` and the values can be of any type (`dynamic`). You can access the values in
  /// the map using
  void _showAttachmentOptions(Map<String, dynamic> attachment) {
    final bool isDownloaded = _downloadedFiles.containsKey(attachment['url']);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDownloaded) ...[
            ListTile(
              leading: Icon(
                attachment['type'] == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                color: Colors.green,
              ),
              title: Text('Open ${attachment['name']}'),
              onTap: () {
                Navigator.pop(context);
                _openDownloadedFile(_downloadedFiles[attachment['url']]!, attachment['type']);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete,
                color: Colors.red,
              ),
              title: Text('Delete ${attachment['name']}'),
              onTap: () async {
                Navigator.pop(context);
                await _deleteDownloadedFile(attachment);
              },
            ),
          ] else ...[
            ListTile(
              leading: Icon(
                attachment['type'] == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                color: AppConstants.primaryColor,
              ),
              title: Text('View ${attachment['name']} Online'),
              onTap: () {
                Navigator.pop(context);
                _showInAppViewer(attachment);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.download,
                color: AppConstants.primaryColor,
              ),
              title: Text('Download ${attachment['name']}'),
              onTap: () {
                Navigator.pop(context);
                _downloadFile(attachment);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _handleDownloadTap(Map<String, dynamic> attachment) async {
    final bool isDownloaded = _downloadedFiles.containsKey(attachment['url']);
    
    if (isDownloaded) {
      // Show confirmation dialog for re-download
      final shouldRedownload = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('File Already Downloaded'),
            content: Text('${attachment['name']} is already saved to your phone. Do you want to download it again?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Re-download'),
              ),
            ],
          );
        },
      );
      
      if (shouldRedownload != true) {
        return;
      }
    }
    
    // Proceed with download
    _downloadFile(attachment);
  }

  void _showInAppViewer(Map<String, dynamic> attachment) async {
    final bool isPDF = attachment['type'] == 'pdf';
    final bool isImage = attachment['type'] == 'image';
    
    try {
      if (isPDF) {
        // Show PDF in app
        _showPdfViewer(attachment);
      } else if (isImage) {
        // Show image in app
        _showImageViewer(attachment);
      } else {
        // For other file types, try to open externally
        final url = Uri.parse(attachment['url']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        } else {
          throw Exception('Could not open file');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPdfViewer(Map<String, dynamic> attachment) async {
    // Check if file is already downloaded
    String? filePath = _downloadedFiles[attachment['url']];
    
    if (filePath == null) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Loading PDF...'),
                ],
              ),
            ),
          );
        },
      );
      
      try {
        // Download the file first
        await _downloadFileForViewing(attachment);
        filePath = _downloadedFiles[attachment['url']];
        Navigator.of(context).pop(); // Close loading dialog
      } catch (e) {
        Navigator.of(context).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error downloading PDF: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    
    if (filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load PDF file'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Show PDF viewer
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.picture_as_pdf,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          attachment['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // PDF Viewer
                Expanded(
                  child: PDFView(
                    filePath: filePath!,
                    enableSwipe: true,
                    swipeHorizontal: false,
                    autoSpacing: true,
                    pageFling: true,
                    pageSnap: true,
                    defaultPage: 0,
                    fitPolicy: FitPolicy.BOTH,
                    preventLinkNavigation: false,
                    onError: (error) {
                      print('PDF Error: $error');
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error loading PDF: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                    onPageError: (page, error) {
                      print('PDF Page Error: $error');
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPdfViewerFromPath(String filePath, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.picture_as_pdf,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // PDF Viewer
                Expanded(
                  child: PDFView(
                    filePath: filePath,
                    enableSwipe: true,
                    swipeHorizontal: false,
                    autoSpacing: true,
                    pageFling: true,
                    pageSnap: true,
                    defaultPage: 0,
                    fitPolicy: FitPolicy.BOTH,
                    preventLinkNavigation: false,
                    onError: (error) {
                      print('PDF Error: $error');
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error loading PDF: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                    onPageError: (page, error) {
                      print('PDF Page Error: $error');
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageViewerFromPath(String filePath, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.image,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Image Viewer
                Expanded(
                  child: InteractiveViewer(
                    child: Image.file(
                      File(filePath),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading image',
                                style: TextStyle(
                                  color: Colors.red[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageViewer(Map<String, dynamic> attachment) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.image,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          attachment['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Image Viewer
                Expanded(
                  child: InteractiveViewer(
                    child: Image.network(
                      attachment['url'],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading image',
                                style: TextStyle(
                                  color: Colors.red[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / 
                                  loadingProgress.expectedTotalBytes!
                                : null,
                            color: AppConstants.primaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentButton(Map<String, dynamic> attachment) {
    final bool isPDF = attachment['type'] == 'pdf';
    final bool isImage = attachment['type'] == 'image';
    final bool isDownloading = _downloadProgress.containsKey(attachment['url']);
    final bool isDownloaded = _downloadedFiles.containsKey(attachment['url']);
    final double progress = _downloadProgress[attachment['url']] ?? 0.0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View Button - Use eye icon for viewing
        IconButton(
          onPressed: () => _showInAppViewer(attachment),
          icon: Icon(
            Icons.visibility,
            size: 20,
            color: AppConstants.primaryColor,
          ),
          tooltip: 'View ${isPDF ? 'PDF' : isImage ? 'Image' : 'File'}',
        ),
        // Download Button - Use download icon
        IconButton(
          onPressed: isDownloading ? null : () => _handleDownloadTap(attachment),
          icon: isDownloading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                  ),
                )
              : Icon(
                  isDownloaded ? Icons.refresh : Icons.download,
                  size: 20,
                  color: isDownloaded ? Colors.orange : AppConstants.primaryColor,
                ),
          tooltip: isDownloading 
              ? 'Downloading... ${(progress * 100).toInt()}%'
              : isDownloaded 
                  ? 'Re-download to phone' 
                  : 'Download to phone',
        ),
      ],
    );
  }

  Widget _buildAnnouncementDetails(Map<String, dynamic> announcement) {
    final typeColor = _getTypeColor(announcement['type']);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(
                  _getTypeIcon(announcement['type']),
                  color: typeColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    announcement['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    announcement['description'],
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Date: ${DateFormat('MMM d, y').format(announcement['date'])}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  if (announcement['attachment'] != null) ...[
                    const SizedBox(height: 16),
                    _buildAttachmentButton(announcement['attachment']),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      color: AppConstants.primaryColor,
      child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FadeSlideTransition(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search announcements...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppConstants.primaryColor),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
          
          // Category Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryCard(
                    'All',
                    Icons.all_inclusive,
                    Colors.blue,
                    () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryCard(
                    'Maintenance',
                    Icons.engineering,
                    Colors.orange,
                    () {
                      setState(() {
                        _searchQuery = 'maintenance';
                        _searchController.text = 'maintenance';
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryCard(
                    'Emergency',
                    Icons.warning_rounded,
                    Colors.red,
                    () {
                      setState(() {
                        _searchQuery = 'emergency';
                        _searchController.text = 'emergency';
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryCard(
                    'Announce',
                    Icons.campaign,
                    Colors.green,
                    () {
                      setState(() {
                        _searchQuery = 'announcement';
                        _searchController.text = 'announcement';
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Announcements List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Announcements',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          _isLoadingAnnouncements
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _announcementError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                            const SizedBox(height: 8),
                            Text('Error loading announcements', 
                                style: TextStyle(color: Colors.red[600])),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadAnnouncements,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 12),
          
          filteredAnnouncements.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.announcement_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No announcements found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredAnnouncements.length,
                  itemBuilder: (context, index) {
                    final announcement = filteredAnnouncements[index];
                    final typeColor = _getTypeColor(announcement['type']);
                    
                    return FadeSlideTransition(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shadowColor: typeColor.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => _buildAnnouncementDetails(announcement),
                            );
                          },
                          onLongPress: announcement['attachment'] != null ? () {
                            _showAttachmentOptions(announcement['attachment']);
                          } : null,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getTypeIcon(announcement['type']),
                                      color: typeColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        announcement['title'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  announcement['description'],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('MMM d, y').format(announcement['date']),
                                      style: const TextStyle(
                                        color: Color.fromARGB(255, 179, 178, 178),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (announcement['attachment'] != null)
                                      _buildAttachmentButton(announcement['attachment']),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                      ],
                    ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String getTitle() {
      switch (_selectedIndex) {
        case 0:
          return 'Home';
        case 1:
          return 'My Reports';
        case 2:
          return 'Feedback';
        case 3:
          return 'Notifications';
        default:
          return 'Home';
      }
    }

    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex == 0) {
          // If on home screen, exit the app directly
          return true;
        } else {
          // If on other screens, navigate back to home
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        }
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: getTitle(),
        ),
        body: _selectedIndex == 0 ? _buildHomeContent() : _screens[_selectedIndex - 1],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            
            // If user tapped on notifications tab, update count
            if (index == 3) {
              _updateNotificationCount();
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppConstants.primaryColor,
          unselectedItemColor: Colors.grey,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'My Reports',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.feedback),
              label: 'Feedback',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications),
                  if (_unreadNotificationCount > 0)
                    Positioned(
                    
                      right: 0,
                      top: -6,
                      // child: Container(
                      //   padding: const EdgeInsets.all(4),
                      //   decoration: BoxDecoration(
                      //     color: Colors.red,
                      //     borderRadius: BorderRadius.circular(10),
                      //   ),
                      //   constraints: const BoxConstraints(
                      //     minWidth: 18,
                      //     minHeight: 18,
                      //   ),
                        child: Text(
                          _unreadNotificationCount > 99 
                              ? '99+' 
                              : '$_unreadNotificationCount',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    // ),
                ],
              ),
              label: 'Notifications',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/report');
          },
          backgroundColor: AppConstants.primaryColor,
          child: const Icon(Icons.power_off,  color: Colors.white),
        ),
      ),
    );
  }
}

class BottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  _BottomNavState createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    int count = await ApiService.fetchUnreadCount();
    setState(() {
      unreadCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      onTap: widget.onTap,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Stack(
            children: [
              const Icon(Icons.notifications),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: 'Notifications',
        ),
      ],
    );
  }
}