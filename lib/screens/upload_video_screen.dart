import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../services/video_service.dart';
import '../services/video_converter_service.dart';
import '../services/url_service.dart';
import '../theme/colors.dart';
import '../constants/tags.dart';
import 'package:path/path.dart' as file_path;
import '../extensions/string_extensions.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _videoService = VideoService();
  final _picker = ImagePicker();
  
  XFile? _videoFile;
  bool _isUploading = false;
  bool _isConverting = false;
  String? _errorMessage;
  String? _statusMessage;
  final Set<String> _selectedTags = {};
  double _uploadProgress = 0.0;

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );
      
      if (video != null) {
        setState(() {
          _isConverting = true;
          _statusMessage = 'Checking video format...';
          _errorMessage = null;
        });

        if (await VideoConverterService.needsConversion(video)) {
          setState(() => _statusMessage = 'Converting video to MP4...');
          final convertedPath = await VideoConverterService.convertToMp4(video);
          
          if (convertedPath == null) {
            setState(() {
              _errorMessage = 'Failed to convert video';
              _isConverting = false;
              _statusMessage = null;
            });
            return;
          }
          
          if (kIsWeb) {
            // For web, convertedPath is a blob URL
            _videoFile = XFile(convertedPath);
          } else {
            // For mobile, convertedPath is a file path
            _videoFile = XFile(convertedPath);
          }
        } else {
          _videoFile = video;
        }

        if (!kIsWeb) {
          final file = File(_videoFile!.path);
          final size = await file.length();
          print('Video size: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
        }
        
        setState(() {
          _isConverting = false;
          _statusMessage = null;
        });
      }
    } catch (e) {
      print('Error picking/converting video: $e');
      setState(() {
        _errorMessage = 'Error processing video: $e';
        _isConverting = false;
        _statusMessage = null;
      });
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) {
      setState(() {
        _errorMessage = 'Please select a video first';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      print('Starting upload...');
      print('Title: ${_titleController.text}');
      print('Description length: ${_descriptionController.text.length}');
      print('Selected tags: ${_selectedTags.join(', ')}');
      print('Video path: ${_videoFile!.path}');
      
      await _videoService.uploadVideo(
        videoFile: _videoFile!,
        title: _titleController.text,
        description: _descriptionController.text,
        tags: _selectedTags.toList(),
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully!')),
        );
        
        // Clean up web resources if needed
        if (kIsWeb && _videoFile != null) {
          UrlService.instance.revokeObjectUrl(_videoFile!.path);
        }
        
        // Clear the form
        setState(() {
          _videoFile = null;
          _titleController.clear();
          _descriptionController.clear();
          _selectedTags.clear();
        });
      }
    } catch (e) {
      print('Upload error: $e');
      setState(() {
        _errorMessage = 'Failed to upload video: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildUploadButton() {
    if (!_isUploading) {
      return GestureDetector(
        onTap: _uploadVideo,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppColors.accent,
          child: Text(
            'Upload',
            style: TextStyle(
              color: AppColors.background,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppColors.accent.withOpacity(0.8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: AppColors.background.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Uploading ${(_uploadProgress * 100).toStringAsFixed(1)}%'.lowercase,
            style: TextStyle(
              color: AppColors.background,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        color: AppColors.background,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Video Selection
            GestureDetector(
              onTap: (_isUploading || _isConverting) ? null : _pickVideo,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppColors.accent,
                child: Text(
                  _videoFile != null ? file_path.basename(_videoFile!.path) : 'Select Video'.lowercase,
                  style: TextStyle(
                    color: AppColors.background,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  TextFormField(
                    controller: _titleController,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Title'.lowercase,
                      labelStyle: TextStyle(color: AppColors.accent),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Description'.lowercase,
                      labelStyle: TextStyle(color: AppColors.accent),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MinecraftTags.all.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTags.remove(tag);
                            } else {
                              _selectedTags.add(tag);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          color: isSelected ? AppColors.accent : null,
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              color: isSelected ? AppColors.background : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],

                  const SizedBox(height: 16),
                  
                  // Upload Button
                  _buildUploadButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 