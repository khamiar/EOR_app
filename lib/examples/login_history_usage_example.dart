/*
 * LOGIN HISTORY USAGE EXAMPLES
 * 
 * This file shows how to integrate the login history functionality
 * into your existing Flutter app.
 */

import 'package:flutter/material.dart';
import '../widgets/login_history_widget.dart';
import '../services/user_history_service.dart';
import '../services/auth_service.dart';

// Example 1: Using LoginHistoryWidget in your login screen
class LoginScreenExample extends StatefulWidget {
  const LoginScreenExample({super.key});

  @override
  _LoginScreenExampleState createState() => _LoginScreenExampleState();
}

class _LoginScreenExampleState extends State<LoginScreenExample> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _loadLastUser();
  }

  // Load the last logged in user's email
  Future<void> _loadLastUser() async {
    final lastEmail = await _authService.getLastLoggedInUserEmail();
    if (lastEmail != null) {
      _emailController.text = lastEmail;
    }
  }

  // Handle user selection from history
  void _onUserSelected(String email, String? fullName) {
    setState(() {
      _emailController.text = email;
      _showHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Email field with history toggle
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                suffixIcon: IconButton(
                  icon: Icon(_showHistory 
                    ? Icons.keyboard_arrow_up 
                    : Icons.keyboard_arrow_down),
                  onPressed: () {
                    setState(() {
                      _showHistory = !_showHistory;
                    });
                  },
                ),
              ),
            ),
            
            // Show login history when toggled
            if (_showHistory)
              LoginHistoryWidget(
                onUserSelected: _onUserSelected,
                maxEntries: 5,
              ),
            
            // Password field
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            
            // Login button
            ElevatedButton(
              onPressed: () async {
                // Your existing login code here
                // The AuthService will automatically save to history
                await _authService.login(
                  _emailController.text, 
                  _passwordController.text
                );
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

// Example 2: Using email autocomplete with frequent emails
class EmailAutocompleteExample extends StatefulWidget {
  const EmailAutocompleteExample({super.key});

  @override
  _EmailAutocompleteExampleState createState() => _EmailAutocompleteExampleState();
}

class _EmailAutocompleteExampleState extends State<EmailAutocompleteExample> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  List<String> _frequentEmails = [];

  @override
  void initState() {
    super.initState();
    _loadFrequentEmails();
  }

  Future<void> _loadFrequentEmails() async {
    final emails = await _authService.getFrequentEmails(limit: 5);
    setState(() {
      _frequentEmails = emails;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return _frequentEmails.where((email) {
          return email.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        _emailController.text = selection;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email),
          ),
        );
      },
    );
  }
}

// Example 3: Managing login history (for settings screen)
class LoginHistoryManagementExample extends StatefulWidget {
  const LoginHistoryManagementExample({super.key});

  @override
  _LoginHistoryManagementExampleState createState() => _LoginHistoryManagementExampleState();
}

class _LoginHistoryManagementExampleState extends State<LoginHistoryManagementExample> {
  final _userHistoryService = UserHistoryService();
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login History')),
      body: Column(
        children: [
          // Show full login history with remove buttons
          Expanded(
            child: LoginHistoryWidget(
              onUserSelected: (email, fullName) {
                // Handle user selection if needed
                print('Selected user: $email');
              },
              showRemoveButton: true,
              maxEntries: 10,
            ),
          ),
          
          // Clear all history button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () async {
                await _authService.clearLoginHistory();
                setState(() {}); // Refresh the widget
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Login history cleared')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Clear All History'),
            ),
          ),
        ],
      ),
    );
  }
}

// Example 4: Direct usage of UserHistoryService
class DirectServiceUsageExample {
  final UserHistoryService _userHistoryService = UserHistoryService();

  Future<void> exampleUsage() async {
    // Get login history
    final history = await _userHistoryService.getLoginHistory();
    print('Login history count: ${history.length}');

    // Check if user exists in history
    final userExists = await _userHistoryService.userExistsInHistory('user@example.com');
    print('User exists in history: $userExists');

    // Get user's last login time
    final lastLoginTime = await _userHistoryService.getUserLastLoginTime('user@example.com');
    print('Last login time: $lastLoginTime');

    // Get frequent emails for autocomplete
    final frequentEmails = await _userHistoryService.getFrequentEmails(limit: 5);
    print('Frequent emails: $frequentEmails');

    // Remove specific user from history
    await _userHistoryService.removeUserFromHistory('user@example.com');

    // Clear all history
    await _userHistoryService.clearLoginHistory();
  }
}

/*
 * INTEGRATION STEPS:
 * 
 * 1. The UserHistoryService is already integrated into your AuthService
 * 2. Every successful login automatically saves to history
 * 3. Use LoginHistoryWidget in your login screen to show recent users
 * 4. Use email autocomplete to suggest frequent emails
 * 5. Add history management in your settings screen
 * 
 * FEATURES INCLUDED:
 * - Automatic login history saving
 * - Last 10 logins stored
 * - Email autocomplete suggestions
 * - User selection from history
 * - Remove individual entries
 * - Clear all history
 * - Last logged in user pre-filled
 * - Duplicate prevention (same email)
 * - Time formatting (Yesterday, 2 days ago, etc.)
 */ 