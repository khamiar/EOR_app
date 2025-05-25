import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:eoreporter_v1/services/api_service.dart';
import 'package:eoreporter_v1/widgets/custom_button.dart';
import 'package:eoreporter_v1/widgets/custom_text_field.dart';
import 'package:eoreporter_v1/widgets/custom_app_bar.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';

class ReportOutageScreen extends StatefulWidget {
  const ReportOutageScreen({super.key});

  @override
  /// The function `_ReportOutageScreenState createState()` returns an instance of
  /// `_ReportOutageScreenState`.
  _ReportOutageScreenState createState() => _ReportOutageScreenState();
}

class _ReportOutageScreenState extends State<ReportOutageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _apiService = ApiService();
  
  String? _imagePath;
  String? _videoPath;
  Position? _currentPosition;
  bool _isLocationLoading = false;
  bool _isSubmitting = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    // Remove automatic location loading on init
  }

  Future<String> _getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String locationName = [
          place.locality,
          place.subLocality,
          place.thoroughfare,
        ].where((part) => part != null && part.isNotEmpty).join(', ');
        
        return locationName.isNotEmpty ? locationName : 'Unknown Location';
      }
      return 'Unknown Location';
    } catch (e) {
      print('Error getting location name: $e');
      return 'Unknown Location';
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location services'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        setState(() => _isLocationLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                duration: Duration(seconds: 5),
              ),
            );
          }
          setState(() => _isLocationLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable them in settings.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        setState(() => _isLocationLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      String locationName = await _getLocationName(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationController.text = locationName;
          _isLocationLoading = false;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _isLocationLoading = false);
      }
    }
  }

  Future<void> _pickImage({ImageSource source = ImageSource.camera}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        setState(() {
          _imagePath = image.path;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo({ImageSource source = ImageSource.camera}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: source);
      
      if (video != null) {
        _videoController?.dispose();
        final controller = VideoPlayerController.file(File(video.path));
        await controller.initialize();
        
        setState(() {
          _videoPath = video.path;
          _videoController = controller;
        });
      }
    } catch (e) {
      print('Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Allow manual location input if GPS is not available
    if (_currentPosition == null && _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a location or enable location services'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _apiService.submitOutageReport(
        title: _titleController.text,
        description: _descriptionController.text,
        location: _locationController.text,
        latitude: _currentPosition?.latitude ?? 0.0,
        longitude: _currentPosition?.longitude ?? 0.0,
        imagePath: _imagePath,
        videoPath: _videoPath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _submitReport(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Report Outage',
        showBackButton: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConstants.primaryColor.withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Report Power Outage',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Help us restore power faster by providing accurate information',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Title Field
                _buildTransparentSection(
                  title: 'Outage Details',
                  icon: Icons.description,
                  child: CustomTextField(
                    controller: _titleController,
                    label: 'Title of Outage',
                    hint: 'Enter a descriptive title for the outage',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title for the outage';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Description Field
                _buildTransparentSection(
                  title: 'Description',
                  icon: Icons.notes,
                  child: CustomTextField(
                    controller: _descriptionController,
                    label: 'Description of Outage',
                    hint: 'Describe the outage in detail (what happened, when, etc.)',
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please describe the outage';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Location Field
                _buildTransparentSection(
                  title: 'Location',
                  icon: Icons.location_on,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: _locationController,
                        label: 'Location of Outage',
                        hint: 'Enter the location name (e.g., Stone Town, Forodhani)',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the location name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      CustomButton(
                        onPressed: _isLocationLoading ? null : _getCurrentLocation,
                        text: _isLocationLoading ? 'Loading...' : 'Get Current Location',
                        icon: _isLocationLoading ? null : Icons.my_location,
                        backgroundColor: Colors.blue,
                        isLoading: _isLocationLoading,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Media Section
                _buildTransparentSection(
                  title: 'Add Media',
                  icon: Icons.photo_camera,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image Preview
                      if (_imagePath != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Image.file(
                                File(_imagePath!),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () => setState(() => _imagePath = null),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Video Preview
                      if (_videoController != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _videoController?.dispose();
                                        _videoController = null;
                                        _videoPath = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Media Buttons
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              onPressed: () => _showMediaPicker(
                                context: context,
                                isImage: true,
                              ),
                              text: _imagePath == null ? 'Add Photo' : 'Change Photo',
                              icon: Icons.camera_alt,
                              backgroundColor: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CustomButton(
                              onPressed: () => _showMediaPicker(
                                context: context,
                                isImage: false,
                              ),
                              text: _videoPath == null ? 'Add Video' : 'Change Video',
                              icon: Icons.videocam,
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                CustomButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  text: 'Submit Report',
                  icon: Icons.send,
                  backgroundColor: AppConstants.primaryColor,
                  isLoading: _isSubmitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransparentSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppConstants.primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConstants.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  void _showMediaPicker({
    required BuildContext context,
    required bool isImage,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isImage ? Icons.camera_alt : Icons.videocam,
                color: AppConstants.primaryColor,
              ),
              title: Text(isImage ? 'Take Photo' : 'Record Video'),
              onTap: () {
                Navigator.pop(context);
                if (isImage) {
                  _pickImage(source: ImageSource.camera);
                } else {
                  _pickVideo(source: ImageSource.camera);
                }
              },
            ),
            ListTile(
              leading: Icon(
                isImage ? Icons.photo_library : Icons.video_library,
                color: AppConstants.primaryColor,
              ),
              title: Text(isImage ? 'Choose from Gallery' : 'Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                if (isImage) {
                  _pickImage(source: ImageSource.gallery);
                } else {
                  _pickVideo(source: ImageSource.gallery);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
} 