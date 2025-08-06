import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onNotificationRead;
  
  const NotificationsScreen({super.key, this.onNotificationRead});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  Set<String> _markingAsReadIds = {}; // Track which notifications are being marked as read
  bool _isMarkingAllAsRead = false; // Track mark all as read loading state

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifications = await apiService.getNotifications();
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(notifications);
        _isLoading = false;
      });
      
      // Notify parent to update notification count after fetching
      widget.onNotificationRead?.call();
      
    } catch (e) {
      String errorMessage = 'Failed to load notifications';
      
      // Provide more specific error messages
      if (e.toString().contains('Network') || e.toString().contains('SocketException')) {
        errorMessage = 'No internet connection. Please check your network and try again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().contains('401') || e.toString().contains('unauthorized')) {
        errorMessage = 'Session expired. Please login again.';
      } else if (e.toString().contains('403')) {
        errorMessage = 'Access denied. Please contact support.';
      } else if (e.toString().contains('404')) {
        errorMessage = 'Notifications service not found.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      }
      
      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
      

    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    final type = notification['type'] ?? 'general';
    final title = notification['title'] ?? 'Notification';
    final body = notification['body'] ?? notification['message'] ?? 'No content';
    final timestamp = notification['createdAt'] != null
        ? DateTime.tryParse(notification['createdAt'])
        : null;
    final isRead = notification['read'] ?? false;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getNotificationIcon(type),
              color: _getNotificationColor(type),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isRead ? Colors.grey[300] : Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isRead ? 'Read' : 'Unread',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isRead ? Colors.grey[700] : Colors.blue[700],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Message content
              const Text(
                'Message:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              
              if (timestamp != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Received:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(timestamp),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              
              // Notification type
              const SizedBox(height: 16),
              const Text(
                'Type:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getNotificationColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getNotificationColor(type).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  type.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getNotificationColor(type),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!isRead)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                final notificationId = notification['id']?.toString();
                if (notificationId != null) {
                  _markNotificationAsRead(notificationId);
                }
              },
              icon: const Icon(Icons.mark_email_read),
              label: const Text('Mark as Read'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(dynamic notification) {
    // Show detail dialog first
    _showNotificationDetails(notification);
    
    // Mark as read if not already read
    final notificationId = notification['id']?.toString();
    if (notificationId != null && !(notification['read'] ?? false)) {
      _markNotificationAsRead(notificationId);
    }

    // Handle specific notification types
    final type = notification['type'] as String?;
    final data = notification['data'] is Map ? notification['data'] as Map<String, dynamic> : null;

    if (type == null || data == null) return;

    switch (type) {
      case 'announcement':
        Navigator.pushNamed(context, '/announcementDetails', arguments: data);
        break;
      default:
        // Already handled by showing the detail dialog
        break;
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    setState(() {
      _markingAsReadIds.add(notificationId);
    });

    try {
      await ApiService().markNotificationAsRead(notificationId);
      setState(() {
        final index = _notifications.indexWhere((n) => n['id']?.toString() == notificationId);
        if (index != -1) {
          _notifications[index]['read'] = true;
        }
        _markingAsReadIds.remove(notificationId);
      });
      
      // Notify parent that notification count should be updated
      widget.onNotificationRead?.call();
      
    } catch (e) {
      setState(() {
        _markingAsReadIds.remove(notificationId);
      });
      

    }
  }

  // Mark all notifications as read
  Future<void> _markAllAsRead() async {
    final unreadNotifications = _notifications.where((n) => !(n['read'] ?? false)).toList();
    if (unreadNotifications.isEmpty) return;

    setState(() {
      _isMarkingAllAsRead = true;
    });

    try {
      // Mark all unread notifications as read
      for (var notification in unreadNotifications) {
        final id = notification['id']?.toString();
        if (id != null) {
          await ApiService().markNotificationAsRead(id);
        }
      }

      setState(() {
        // Update all notifications to read
        for (var notification in _notifications) {
          notification['read'] = true;
        }
        _isMarkingAllAsRead = false;
      });

      // Notify parent to update count
      widget.onNotificationRead?.call();


    } catch (e) {
      setState(() {
        _isMarkingAllAsRead = false;
      });


    }
  }

  // Check if there are unread notifications
  bool get hasUnreadNotifications {
    return _notifications.any((n) => !(n['read'] ?? false));
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(dateTime);
    } else if (difference.inDays > 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inHours > 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 1) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Oops! Something went wrong',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchNotifications,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No notifications',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Unread notifications banner
                        if (hasUnreadNotifications)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[50]!, Colors.blue[100]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.mark_email_unread,
                                  color: Colors.blue[600],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'You have unread notifications',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[800],
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap the button below to mark all as read',
                                        style: TextStyle(
                                          color: Colors.blue[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _isMarkingAllAsRead
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                        ),
                                      )
                                    : IconButton(
                                        onPressed: _markAllAsRead,
                                        icon: Icon(
                                          Icons.done_all,
                                          color: Colors.blue[600],
                                        ),
                                        tooltip: 'Mark all as read',
                                      ),
                              ],
                            ),
                          ),
                        
                        // Notifications list
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _fetchNotifications,
                            color: AppConstants.primaryColor,
                      child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final isRead = notification['read'] ?? false;
                          final timestamp = notification['createdAt'] != null
                              ? DateTime.tryParse(notification['createdAt'])
                              : null;

                          return Dismissible(
                            key: Key(notification['id'].toString()),
                            direction: DismissDirection.horizontal,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 24),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            secondaryBackground: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) async {
                              final id = notification['id'];
                              final success = await apiService.deleteNotification(id);
                              if (success) {
                                setState(() {
                                  _notifications.removeAt(index);
                                });
                                      
                                      // Notify parent that notification count should be updated
                                      widget.onNotificationRead?.call();
                              } else {
                                setState(() {});
                              }
                            },
                            child: Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => _handleNotificationTap(notification),
                                      borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                          padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                                  padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: _getNotificationColor(notification['type'] ?? '')
                                                .withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _getNotificationIcon(notification['type'] ?? ''),
                                            color: _getNotificationColor(notification['type'] ?? ''),
                                                    size: 24,
                                          ),
                                        ),
                                                const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                notification['title']?.toString() ?? 'Notification',
                                                style: TextStyle(
                                                  fontWeight:
                                                      isRead ? FontWeight.normal : FontWeight.bold,
                                                        fontSize: 18,
                                                ),
                                              ),
                                                    const SizedBox(height: 8),
                                              Text(
                                                notification['body']?.toString() ??
                                                    notification['message']?.toString() ??
                                                    'No content',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                              if (timestamp != null) ...[
                                                      const SizedBox(height: 8),
                                                Text(
                                                  _formatDateTime(timestamp),
                                                  style: TextStyle(
                                                    color: Colors.grey[500],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppConstants.primaryColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: AppConstants.primaryColor.withOpacity(0.5),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          color: AppConstants.primaryColor,
                                              shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'New',
                                                        style: TextStyle(
                                                          color: AppConstants.primaryColor,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              // Show loading indicator if marking as read
                                              if (_markingAsReadIds.contains(notification['id']?.toString()))
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 8),
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                                    ),
                                            ),
                                          ),
                                      ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'outage_report':
        return Colors.orange;
      case 'announcement':
        return Colors.blue;
      case 'feedback_response':
        return Colors.green;
      case 'profile_update':
        return Colors.purple;
      default:
        return Colors.yellow;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'outage_report':
        return Icons.info;
      case 'announcement':
        return Icons.announcement;
      case 'feedback_response':
        return Icons.feedback;
      case 'profile_update':
        return Icons.person;
      default:
        return Icons.notifications;
    }
  }

  // ignore: unused_element
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}