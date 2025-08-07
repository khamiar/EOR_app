import 'package:flutter/material.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';
import 'package:eoreporter_v1/widgets/custom_app_bar.dart';
import 'package:eoreporter_v1/services/auth_service.dart';
import 'package:eoreporter_v1/models/user.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  final AuthService _authService = AuthService();
  User? _currentUser;
  bool _isLoading = true;
  File? _pickedImage;
  String? _localProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLocalProfileImageUrl();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final localUrl = prefs.getString('profileImageUrl');

    try {
      print('PROFILE: Loading user data...');
      final user = await _authService.getCurrentUser();
      print('PROFILE: User loaded: ${user?.email}');
      
      if (mounted) {
        setState(() {
          _currentUser = user?.copyWith(profileImageUrl: localUrl ?? user.profileImageUrl);
          _nameController.text = user?.fullName ?? '';
          _emailController.text = user?.email ?? '';
          _phoneController.text = user?.phoneNumber ?? '';
          _addressController.text = user?.address ?? '';
          _isLoading = false;
        });
        print('PROFILE: User data set successfully');
      }
    } catch (e) {
      print('PROFILE: Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadLocalProfileImageUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _localProfileImageUrl = prefs.getString('profileImageUrl');
    });
  }



  String _getInitials(String? fullName, String? email) {
    if (fullName != null && fullName.isNotEmpty) {
      final names = fullName.trim().split(' ');
      if (names.length >= 2) {
        return '${names[0][0]}${names[1][0]}'.toUpperCase();
      } else if (names.isNotEmpty) {
        return names[0][0].toUpperCase();
      }
    }
    
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    
    return 'U';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _showEditDialog(String field, String currentValue, String title, IconData icon) {
    final controller = TextEditingController(text: currentValue);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: AppConstants.primaryColor),
              const SizedBox(width: 8),
              Text('Edit $title'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: title,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement API call to update the field
    setState(() {
                  switch (field) {
                    case 'name':
                      _nameController.text = controller.text;
                      break;
                    case 'email':
                      _emailController.text = controller.text;
                      break;
                    case 'phone':
                      _phoneController.text = controller.text;
                      break;
                    case 'address':
                      _addressController.text = controller.text;
                      break;
                  }
                });
                Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$title updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, String field) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showEditDialog(field, value, title, icon),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppConstants.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.isEmpty ? 'Not set' : value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: CustomAppBar(
          title: 'Profile',
          showBackButton: true,
          onBackPressed: () {
            Navigator.of(context).pushReplacementNamed('/home');
          },
          showProfileAvatar: false,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Profile',
        showBackButton: true,
        onBackPressed: () {
          Navigator.of(context).pushReplacementNamed('/home');
        },
        showProfileAvatar: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Picture with Initials
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppConstants.primaryColor,
                    backgroundImage: _localProfileImageUrl != null && _localProfileImageUrl!.isNotEmpty
                        ? NetworkImage(_localProfileImageUrl!)
                        : null,
                    child: (_localProfileImageUrl == null || _localProfileImageUrl!.isEmpty)
                        ? Text(
                            _getInitials(_currentUser?.fullName, _currentUser?.email),
                            style: const TextStyle(fontSize: 36, color: Colors.white),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _currentUser?.fullName ?? 'User',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _currentUser?.email ?? '',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              
            // Profile Info Cards
            _buildInfoCard('Full Name', _nameController.text, Icons.person, 'name'),
            _buildInfoCard('Email', _emailController.text, Icons.email, 'email'),
            _buildInfoCard('Phone Number', _phoneController.text, Icons.phone, 'phone'),
            _buildInfoCard('Address', _addressController.text, Icons.location_on, 'address'),
          ],
        ),
      ),
    );
  }
} 