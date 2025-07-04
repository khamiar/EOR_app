import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FeedbackTestWidget extends StatefulWidget {
  const FeedbackTestWidget({Key? key}) : super(key: key);

  @override
  State<FeedbackTestWidget> createState() => _FeedbackTestWidgetState();
}

class _FeedbackTestWidgetState extends State<FeedbackTestWidget> {
  final ApiService _apiService = ApiService();
  String _testResult = 'Ready to test';
  bool _isLoading = false;

  Future<void> _testFeedbackAPI() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing API...';
    });

    try {
      // Test 1: Submit feedback
      print('=== TESTING FEEDBACK SUBMISSION ===');
      final response = await _apiService.submitFeedback(
        subject: 'Test Feedback',
        message: 'This is a test message to verify the API is working.',
      );
      
      print('Submit response: $response');
      
      // Test 2: Get feedback
      print('=== TESTING FEEDBACK RETRIEVAL ===');
      final feedbackList = await _apiService.getMyFeedback();
      
      print('Feedback list: $feedbackList');
      
      setState(() {
        _testResult = '''
✅ API Test Successful!

Submit Response:
${response.toString()}

Feedback Count: ${feedbackList.length}

Recent Feedback:
${feedbackList.isNotEmpty ? feedbackList.first.toString() : 'No feedback found'}
        ''';
        _isLoading = false;
      });
      
    } catch (e) {
      print('API Test Error: $e');
      setState(() {
        _testResult = '''
❌ API Test Failed!

Error: ${e.toString()}

Check console logs for more details.
        ''';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback API Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This utility tests the feedback API connection',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _testFeedbackAPI,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Test Feedback API'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Test Results:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResult,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 