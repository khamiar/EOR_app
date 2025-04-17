import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';
import 'package:eoreporter_v1/utils/animations.dart';
import 'package:eoreporter_v1/widgets/custom_app_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ReportOutageScreen extends StatefulWidget {
  const ReportOutageScreen({super.key});

  @override
  State<ReportOutageScreen> createState() => _ReportOutageScreenState();
}

class _ReportOutageScreenState extends State<ReportOutageScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _manualLocationController = TextEditingController();
  final _imagePicker = ImagePicker();
  File? _selectedImage;
  File? _selectedVideo;
  bool _isSubmitting = false;
  late final AnimationController _submitController;
  String? _selectedCategory;

  final List<String> _categories = [
    'Power Outage',
    'Water Outage',
    'Internet Outage',
    'Gas Outage',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _submitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          _submitController.reset();
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _manualLocationController.dispose();
    _submitController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to take photos'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _selectedVideo = null; // Clear video if image is selected
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to record videos'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final pickedFile = await _imagePicker.pickVideo(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedVideo = File(pickedFile.path);
          _selectedImage = null; // Clear image if video is selected
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking video: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text('Record Video'),
            onTap: () {
              Navigator.pop(context);
              _pickVideo(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Choose Video from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickVideo(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      if (!mounted) return;
      
      setState(() => _isSubmitting = true);
      
      try {
        // Animate the submit button
        await _submitController.forward();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Report submitted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }

        // Reset form
        _formKey.currentState!.reset();
        if (mounted) {
          setState(() {
            _selectedImage = null;
            _selectedVideo = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting report: ${e.toString()}'),
              backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Report Outage'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: FadeSlideTransition(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title Field
                FadeSlideTransition(
                  duration: const Duration(milliseconds: 600),
                  child: TextFormField(
                    controller: _titleController,
                    decoration: FormStyles.inputDecoration(
                      label: 'Title',
                      hint: 'Enter outage title',
                      prefixIcon: Icons.title,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      if (value.length < 5) {
                        return 'Title should be at least 5 characters';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Manual Location Field (Optional)
                FadeSlideTransition(
                  duration: const Duration(milliseconds: 650),
                  child: TextFormField(
                    controller: _manualLocationController,
                    decoration: FormStyles.inputDecoration(
                      label: 'Manual Location (Optional)',
                      hint: 'Enter location if automatic detection fails',
                      prefixIcon: Icons.location_on,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Category Field
                FadeSlideTransition(
                  duration: const Duration(milliseconds: 600),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: FormStyles.inputDecoration(
                      label: 'Category',
                      hint: 'Select outage category',
                      prefixIcon: Icons.category,
                    ),
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a category';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Description Field
                FadeSlideTransition(
                  duration: const Duration(milliseconds: 700),
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: FormStyles.inputDecoration(
                      label: 'Description',
                      hint: 'Describe the outage in detail',
                      prefixIcon: Icons.description,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a description';
                      }
                      if (value.length < 10) {
                        return 'Description should be at least 10 characters';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Media Section
                FadeSlideTransition(
                  duration: const Duration(milliseconds: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Media (Optional)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showMediaOptions,
                              icon: const Icon(Icons.add_a_photo),
                              label: const Text('Add Media'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedImage != null || _selectedVideo != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _selectedImage != null
                                ? Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  )
                                : _selectedVideo != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          const Icon(
                                            Icons.videocam,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                          Positioned(
                                            bottom: 8,
                                            right: 8,
                                            child: IconButton(
                                              icon: const Icon(Icons.delete),
                                              onPressed: () {
                                                setState(() {
                                                  _selectedVideo = null;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Submit Button
                FadeSlideTransition(
                  duration: const Duration(milliseconds: 900),
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
                            onPressed: _isSubmitting ? null : _submitReport,
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
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send),
                                      SizedBox(width: 8),
                                      Text(
                                        'Submit Report',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
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