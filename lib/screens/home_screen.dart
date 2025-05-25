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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Widget> _screens = [];
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadedFiles = {};
  Directory? _downloadDirectory;
  final Dio _dio = Dio();

  // Dummy announcements data
  final List<Map<String, dynamic>> announcements = [
    {
      'title': 'Scheduled Maintenance',
      'description': 'Power maintenance in downtown area from 10 PM to 4 AM',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'type': 'maintenance',
      'attachment': {
        'url': 'https://example.com/maintenance.pdf',
        'name': 'maintenance_schedule.pdf',
        'type': 'pdf'
      }
    },
    {
      'title': 'Emergency Outage',
      'description': 'Unexpected power outage in north district due to storm',
      'date': DateTime.now(),
      'type': 'emergency',
      'attachment': {
        'url': 'https://example.com/outage.jpg',
        'name': 'outage_area.jpg',
        'type': 'image'
      }
    },
    {
      'title': 'New Solar Initiative',
      'description': 'ZECO launching new solar power initiative for residential areas',
      'date': DateTime.now().add(const Duration(days: 1)),
      'type': 'announcement',
      'attachment': null
    },
  ];

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      const MyReportsScreen(),
      const FeedbackScreen(),
      const NotificationsScreen(),
    ]);
    _initializeDownloadDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _downloadFile(Map<String, dynamic> attachment) async {
    if (_downloadedFiles.containsKey(attachment['url'])) {
      _openDownloadedFile(_downloadedFiles[attachment['url']]!, attachment['type']);
      return;
    }

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

      final filePath = Platform.isWindows
          ? '${_downloadDirectory!.path}\\${attachment['name']}'
          : '${_downloadDirectory!.path}/${attachment['name']}';

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
                  child: Text('${attachment['name']} downloaded successfully'),
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
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw Exception('Could not open file');
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
                _handleAttachmentTap(attachment);
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

  void _handleAttachmentTap(Map<String, dynamic> attachment) async {
    final url = Uri.parse(attachment['url']);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open attachment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAttachmentButton(Map<String, dynamic> attachment) {
    final bool isPDF = attachment['type'] == 'pdf';
    final bool isDownloading = _downloadProgress.containsKey(attachment['url']);
    final bool isDownloaded = _downloadedFiles.containsKey(attachment['url']);
    final double progress = _downloadProgress[attachment['url']] ?? 0.0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View Button
        IconButton(
          onPressed: () => _handleAttachmentTap(attachment),
          icon: Icon(
            isPDF ? Icons.picture_as_pdf : Icons.image,
            size: 20,
            color: AppConstants.primaryColor,
          ),
          tooltip: 'View ${isPDF ? 'PDF' : 'Image'}',
        ),
        // Download Button
        IconButton(
          onPressed: isDownloading ? null : () => _downloadFile(attachment),
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
                  isDownloaded ? Icons.check_circle : Icons.download,
                  size: 20,
                  color: isDownloaded ? Colors.green : AppConstants.primaryColor,
                ),
          tooltip: isDownloading 
              ? 'Downloading... ${(progress * 100).toInt()}%'
              : isDownloaded 
                  ? 'Downloaded' 
                  : 'Download',
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
    return SingleChildScrollView(
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
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppConstants.primaryColor,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'My Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.feedback),
              label: 'Feedback',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'Notifications',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/report');
          },
          backgroundColor: AppConstants.primaryColor,
          child: const Icon(Icons.power_off,  color: Colors.red),
        ),
      ),
    );
  }
} 