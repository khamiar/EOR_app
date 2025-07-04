import 'package:flutter/material.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';
import 'package:eoreporter_v1/utils/animations.dart';
import 'package:eoreporter_v1/services/api_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _apiService = ApiService();
  late AnimationController _submitController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _submitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _submitController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isSubmitting = false);
        _submitController.reset();
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _submitController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      
      try {
        // Submit feedback to backend
        final response = await _apiService.submitFeedback(
          subject: _subjectController.text.trim(),
          message: _messageController.text.trim(),
        );
      
      // Animate the submit button
      await _submitController.forward();

        if (mounted) {
          // Extract message safely from response
          String successMessage = 'Feedback submitted successfully';
          if (response is Map<String, dynamic> && response.containsKey('message')) {
            successMessage = response['message']?.toString() ?? successMessage;
          }

      // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Row(
              children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(successMessage),
                  ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
              duration: const Duration(seconds: 4),
          ),
        );

      // Reset form
          _subjectController.clear();
          _messageController.clear();
      _formKey.currentState!.reset();
        }
      } catch (e) {
        if (mounted) {
          // Show error message
          String errorMessage = e.toString();
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring('Exception: '.length);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(errorMessage),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: const CustomAppBar(title: 'Feedback'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: FadeSlideTransition(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with bounce animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: const Icon(
                    Icons.feedback_outlined,
                    size: 64,
                    color: AppConstants.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                const ScaleInTransition(
                  duration: Duration(milliseconds: 400),
                  child: Text(
                    'We Value Your Feedback',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ScaleInTransition(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    'Help us improve our service by sharing your thoughts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Subject Field with hover effect
                MouseRegion(
                  onEnter: (_) => setState(() {}),
                  onExit: (_) => setState(() {}),
                  child: FadeSlideTransition(
                    duration: const Duration(milliseconds: 600),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.primaryColor.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _subjectController,
                        decoration: FormStyles.inputDecoration(
                          label: 'Subject',
                          hint: 'Enter feedback subject',
                          prefixIcon: Icons.subject,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a subject';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Message Field with hover effect
                MouseRegion(
                  onEnter: (_) => setState(() {}),
                  onExit: (_) => setState(() {}),
                  child: FadeSlideTransition(
                    duration: const Duration(milliseconds: 700),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.primaryColor.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _messageController,
                        maxLines: 5,
                        decoration: FormStyles.inputDecoration(
                          label: 'Message',
                          hint: 'Enter your feedback message',
                          prefixIcon: Icons.message,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a message';
                          }
                          if (value.length < 10) {
                            return 'Message should be at least 10 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Animated Submit Button
                FadeSlideTransition(
                  duration: const Duration(milliseconds: 800),
                  child: AnimatedBuilder(
                    animation: _submitController,
                    builder: (context, child) {
                      final buttonWidth = _isSubmitting
                          ? 50.0
                          : MediaQuery.of(context).size.width;
                      
                      return Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: buttonWidth,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitFeedback,
                            style: FormStyles.elevatedButtonStyle().copyWith(
                              backgroundColor: WidgetStateProperty.all(
                                _isSubmitting
                                    ? Colors.green
                                    : AppConstants.primaryColor,
                              ),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    _isSubmitting ? 25 : 12,
                                  ),
                                ),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.send),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                        'Submit Feedback',
                                          style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 