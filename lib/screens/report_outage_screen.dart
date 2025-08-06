import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:eoreporter_v1/services/api_service.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';
import 'package:eoreporter_v1/widgets/custom_app_bar.dart';

class ReportOutageScreen extends StatefulWidget {
  const ReportOutageScreen({super.key});

  @override
  _ReportOutageScreenState createState() => _ReportOutageScreenState();
}

class _ReportOutageScreenState extends State<ReportOutageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _regionController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _apiService = ApiService();

  String? _imagePath;
  String? _videoPath;
  Position? _currentPosition;
  bool _isLocationLoading = false;
  bool _isSubmitting = false;
  VideoPlayerController? _videoController;

  // Define your categories
  final List<String> _categories = [
    'Emergency',
    'Planned Maintenance',
    'Partial Outage',
    'Total Outage',
    'Other',
  ];

final List<String> _regions = [
  'Mjini Magharibi',
  'Kaskazini Unguja',
  'Kusini Unguja',
  'Kaskazini Pemba',
  'Kusini Pemba'
];


  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _autoFillLocation();
  }

  Future<void> _autoFillLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocationLoading = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocationLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
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
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
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
        region: _regionController.text,
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
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              const Text(
                'Report Power Outage',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
              Text(
                'Help us restore power faster by providing accurate information.',
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),

              // Category Field
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category of Outage',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _titleController.text = value ?? '';
                  });
                },
                validator: (value) => value == null || value.isEmpty ? 'Please select a category' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _regionController.text.isEmpty ? null : _regionController.text,
                decoration: InputDecoration(
                  labelText: 'Region',
                  prefixIcon: const Icon(Icons.map),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _regions.map((region) {
                  return DropdownMenuItem<String>(
                    value: region,
                    child: Text(region),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _regionController.text = value ?? '';
                  });
                },
                validator: (value) => value == null || value.isEmpty ? 'Please select a region' : null,
              ),
              const SizedBox(height: 20),
              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: const Icon(Icons.notes),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 4,
                validator: (value) => value == null || value.isEmpty ? 'Please describe the outage' : null,
              ),
              const SizedBox(height: 20),

              // Location Field
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter the location' : null,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLocationLoading ? null : _getCurrentLocation,
                  icon: _isLocationLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, color: AppConstants.primaryColor),
                  label: Text(
                    _isLocationLoading ? 'Loading...' : 'Get Current Location',
                    style: const TextStyle(color: AppConstants.primaryColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppConstants.primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Media Section
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _imagePath != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_imagePath!),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => setState(() => _imagePath = null),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              if (_imagePath != null) const SizedBox(height: 12),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _videoController != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _videoController?.dispose();
                                  _videoController = null;
                                  _videoPath = null;
                                });
                              },
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              if (_videoController != null) const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(source: ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, color: AppConstants.primaryColor),
                      label: const Text('Add Photo', style: TextStyle(color: AppConstants.primaryColor)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppConstants.primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickVideo(source: ImageSource.camera),
                      icon: const Icon(Icons.videocam, color: AppConstants.primaryColor),
                      label: const Text('Add Video', style: TextStyle(color: AppConstants.primaryColor)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppConstants.primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isSubmitting
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit Report', key: ValueKey('text')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}