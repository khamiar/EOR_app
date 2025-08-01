import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

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
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load notifications: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _handleNotificationTap(dynamic notification) {
    final type = notification['type'] as String?;
    final data = notification['data'] is Map ? notification['data'] as Map<String, dynamic> : null;
    final notificationId = notification['id']?.toString();
    
    if (notificationId != null && !(notification['read'] ?? false)) {
      _markNotificationAsRead(notificationId);
    }

    if (type == null || data == null) return;

    switch (type) {
      case 'announcement':
        Navigator.pushNamed(context, '/announcementDetails', arguments: data);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unknown notification type')),
        );
    }


  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await ApiService().markNotificationAsRead(notificationId);
      setState(() {
        final index = _notifications.indexWhere((n) => n['id']?.toString() == notificationId);
        if (index != -1) {
          _notifications[index]['read'] = true;
        }
      });
    } catch (e) {
      // Show error message if marking as read fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark notification as read')),
        );
      }
    }
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
              ? Center(child: Text(_errorMessage!))
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
                  : RefreshIndicator(
                      onRefresh: _fetchNotifications, // <-- fix here
                      child: ListView.builder(
                        padding: EdgeInsets.zero, // Remove horizontal padding
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Notification deleted')),
                                );
                              } else {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to delete notification')),
                                );
                              }
                            },
                            child: Card(
                              margin: EdgeInsets.zero,
                              elevation: 0,
                              color: Colors.transparent,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              child: InkWell(
                                onTap: () => _handleNotificationTap(notification),
                                borderRadius: BorderRadius.zero,
                                child: Container(
                                  width: double.infinity, // Ensure full width
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white,
                                        Colors.grey[100]!,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border(
                                      left: BorderSide(
                                        color: _getNotificationColor(notification['type'] ?? ''),
                                        width: 4,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.zero,
                                    boxShadow: [],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8), // No horizontal padding
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _getNotificationColor(notification['type'] ?? '')
                                                .withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getNotificationIcon(notification['type'] ?? ''),
                                            color: _getNotificationColor(notification['type'] ?? ''),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                notification['title']?.toString() ?? 'Notification',
                                                style: TextStyle(
                                                  fontWeight:
                                                      isRead ? FontWeight.normal : FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
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
                                                const SizedBox(height: 4),
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
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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