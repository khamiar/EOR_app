import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/login_history_model.dart';
import '../services/user_history_service.dart';

class LoginHistoryWidget extends StatefulWidget {
  final Function(String email, String? fullName)? onUserSelected;
  final bool showRemoveButton;
  final int maxEntries;

  const LoginHistoryWidget({
    Key? key,
    this.onUserSelected,
    this.showRemoveButton = true,
    this.maxEntries = 5,
  }) : super(key: key);

  @override
  State<LoginHistoryWidget> createState() => _LoginHistoryWidgetState();
}

class _LoginHistoryWidgetState extends State<LoginHistoryWidget> {
  final UserHistoryService _userHistoryService = UserHistoryService();
  List<LoginHistoryEntry> _loginHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLoginHistory();
  }

  Future<void> _loadLoginHistory() async {
    try {
      final history = await _userHistoryService.getLoginHistory();
      setState(() {
        _loginHistory = history.take(widget.maxEntries).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeUserFromHistory(String email) async {
    try {
      await _userHistoryService.removeUserFromHistory(email);
      await _loadLoginHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User removed from history'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove user from history'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat('MMM dd, yyyy').format(dateTime);
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_loginHistory.isEmpty) {
      return const Center(
        child: Text(
          'No login history found',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Logins',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _loginHistory.length,
          itemBuilder: (context, index) {
            final entry = _loginHistory[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(
                    entry.fullName?.isNotEmpty == true
                        ? entry.fullName![0].toUpperCase()
                        : entry.email[0].toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  entry.fullName?.isNotEmpty == true
                      ? entry.fullName!
                      : entry.email,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.fullName?.isNotEmpty == true)
                      Text(
                        entry.email,
                        style: const TextStyle(fontSize: 12),
                      ),
                    Text(
                      _formatDateTime(entry.loginTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                trailing: widget.showRemoveButton
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => _removeUserFromHistory(entry.email),
                        tooltip: 'Remove from history',
                      )
                    : null,
                onTap: widget.onUserSelected != null
                    ? () => widget.onUserSelected!(entry.email, entry.fullName)
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}

// Widget for autocomplete email suggestions
class EmailAutocompleteWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String)? onSelected;

  const EmailAutocompleteWidget({
    Key? key,
    required this.controller,
    this.onSelected,
  }) : super(key: key);

  @override
  State<EmailAutocompleteWidget> createState() => _EmailAutocompleteWidgetState();
}

class _EmailAutocompleteWidgetState extends State<EmailAutocompleteWidget> {
  final UserHistoryService _userHistoryService = UserHistoryService();
  List<String> _frequentEmails = [];

  @override
  void initState() {
    super.initState();
    _loadFrequentEmails();
  }

  Future<void> _loadFrequentEmails() async {
    try {
      final emails = await _userHistoryService.getFrequentEmails();
      setState(() {
        _frequentEmails = emails;
      });
    } catch (e) {
      // Handle error silently
    }
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
        widget.controller.text = selection;
        if (widget.onSelected != null) {
          widget.onSelected!(selection);
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          onFieldSubmitted: (value) => onFieldSubmitted(),
        );
      },
    );
  }
} 