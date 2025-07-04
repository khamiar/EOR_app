import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';
import 'package:eoreporter_v1/services/api_service.dart';
import 'package:eoreporter_v1/models/feedback_model.dart';
import 'package:eoreporter_v1/widgets/custom_app_bar.dart';

class MyFeedbackScreen extends StatefulWidget {
  const MyFeedbackScreen({super.key});

  @override
  State<MyFeedbackScreen> createState() => _MyFeedbackScreenState();
}

class _MyFeedbackScreenState extends State<MyFeedbackScreen> {
  final ApiService _apiService = ApiService();
  List<FeedbackModel> _feedbackList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final feedbackData = await _apiService.getMyFeedback();
      
      List<FeedbackModel> parsedFeedback = [];
      
      for (int i = 0; i < feedbackData.length; i++) {
        try {
          final feedbackItem = feedbackData[i];
          
          if (feedbackItem is Map<String, dynamic>) {
            final feedback = FeedbackModel.fromJson(feedbackItem);
            parsedFeedback.add(feedback);
          }
        } catch (parseError) {
          // Continue with other items instead of failing completely
          debugPrint('Error parsing feedback item $i: $parseError');
        }
      }
      
      setState(() {
        _feedbackList = parsedFeedback;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshFeedback() async {
    await _loadFeedback();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'REVIEWED':
        return Colors.blue;
      case 'RESOLVED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.schedule;
      case 'REVIEWED':
        return Icons.visibility;
      case 'RESOLVED':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  Widget _buildFeedbackCard(FeedbackModel feedback) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showFeedbackDetails(feedback),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      feedback.subject,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(feedback.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(feedback.status),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(feedback.status),
                          size: 14,
                          color: _getStatusColor(feedback.status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          feedback.statusDisplayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(feedback.status),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                feedback.message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy - HH:mm').format(feedback.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (feedback.hasResponse)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Response Available',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeedbackDetails(FeedbackModel feedback) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feedback.subject),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Status: ${feedback.statusDisplayName}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(feedback.status),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Submitted: ${DateFormat('MMM dd, yyyy - HH:mm').format(feedback.createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text(
                'Message:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(feedback.message),
              if (feedback.hasResponse) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    const Text(
                      'Admin Response:',
                      style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Text(feedback.response!),
                ),
                if (feedback.respondedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Responded: ${DateFormat('MMM dd, yyyy - HH:mm').format(feedback.respondedAt!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'My Feedback',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFeedback,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadFeedback,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _feedbackList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.feedback_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No feedback submitted yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Submit your first feedback to see it here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _feedbackList.length,
                        itemBuilder: (context, index) {
                          return _buildFeedbackCard(_feedbackList[index]);
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/feedback').then((_) {
            // Refresh the list when returning from feedback screen
            _loadFeedback();
          });
        },
        backgroundColor: AppConstants.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
} 