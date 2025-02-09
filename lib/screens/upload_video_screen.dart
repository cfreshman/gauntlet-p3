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
import 'package:video_player/video_player.dart';

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
  bool _isCreatingPost = false;
  bool _isProcessingVideo = false;
  String? _errorMessage;
  String? _statusMessage;
  final Set<String> _selectedTags = {};
  String? _videoUrl;
  String? _thumbnailUrl;
  int? _durationMs;
  double _uploadProgress = 0.0;

  static const int _maxSizeMB = 500;  // 500MB limit
  static const Duration _maxDuration = Duration(minutes: 10);

  Future<void> _pickVideo() async {
    if (_isCreatingPost || _isProcessingVideo) return;

    try {
      setState(() {
        _isProcessingVideo = true;
        _statusMessage = 'selecting video...';
        _errorMessage = null;
        _durationMs = null;
        _uploadProgress = 0.0;
      });

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: _maxDuration,
      );
      
      if (video == null) {
        setState(() {
          _isProcessingVideo = false;
          _statusMessage = null;
        });
        return;
      }

      // Check file size
      final int fileSize = await video.length();
      final int maxSize = _maxSizeMB * 1024 * 1024; // Convert MB to bytes
      if (fileSize > maxSize) {
        setState(() {
          _errorMessage = 'video too large (max ${_maxSizeMB}MB)';
          _isProcessingVideo = false;
          _statusMessage = null;
          _videoFile = null;
        });
        return;
      }

      setState(() {
        _statusMessage = 'uploading video...';
        _videoFile = video;
        _thumbnailUrl = null;
        _videoUrl = null;
      });

      // Process video with progress
      final processedVideo = await VideoConverterService.convertToMp4(
        _videoFile!,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              if (progress >= 1.0) {
                _statusMessage = 'processing video...';
              }
            });
          }
        },
      );

      if (processedVideo == null) {
        throw Exception('Failed to process video');
      }

      setState(() {
        _videoUrl = processedVideo['videoUrl'];
        _thumbnailUrl = processedVideo['thumbnailUrl'];
        _durationMs = processedVideo['durationMs'];
        _isProcessingVideo = false;
        _statusMessage = null;
        _uploadProgress = 0.0;
      });

      // Show success message with size info
      if (mounted) {
        final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'video processed and ready ($sizeMB MB)'.toLowerCase(),
              style: TextStyle(color: AppColors.background),
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error picking/converting video: $e');
      setState(() {
        _errorMessage = 'Error processing video: $e';
        _isProcessingVideo = false;
        _statusMessage = null;
        _videoFile = null;
      });
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null || _videoUrl == null || !_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isCreatingPost = true;
        _errorMessage = null;
      });

      // Process video first
      setState(() => _statusMessage = 'processing video...');
      final processedVideo = await VideoConverterService.convertToMp4(_videoFile!);
      if (processedVideo == null) {
        throw Exception('Failed to process video');
      }

      // Get video info from cloud function result
      final result = await _videoService.uploadVideo(
        title: _titleController.text,
        description: _descriptionController.text,
        tags: _selectedTags,
        videoUrl: processedVideo['videoUrl'],
        thumbnailUrl: processedVideo['thumbnailUrl'],
        durationMs: processedVideo['durationMs'],
      );

      if (mounted) {
        setState(() {
          _videoUrl = processedVideo['videoUrl'];
          _thumbnailUrl = processedVideo['thumbnailUrl'];
          _durationMs = processedVideo['durationMs'];
          _isCreatingPost = false;
          _statusMessage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'post created!'.toLowerCase(),
              style: TextStyle(color: AppColors.background),
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Reset form after short delay to show completion
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _videoFile = null;
              _videoUrl = null;
              _thumbnailUrl = null;
              _durationMs = null;
              _titleController.clear();
              _descriptionController.clear();
              _selectedTags.clear();
            });
          }
        });
      }
    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        setState(() {
          _isCreatingPost = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Widget _buildVideoSelector() {
    return GestureDetector(
      onTap: (_isCreatingPost || _isProcessingVideo) ? null : _pickVideo,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: (_isCreatingPost || _isProcessingVideo) 
            ? AppColors.accent.withOpacity(0.5)
            : AppColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (_thumbnailUrl != null) ...[
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                child: Image.network(
                  _thumbnailUrl!,
                  height: 120,
                  width: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading thumbnail: $error');
                    return Container(
                      height: 120,
                      width: 160,
                      color: AppColors.background.withOpacity(0.1),
                      child: Icon(
                        Icons.image_not_supported,
                        size: 32,
                        color: AppColors.background,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isProcessingVideo && _statusMessage != null) ...[
                    if (_uploadProgress > 0 && _uploadProgress < 1) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: AppColors.background.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.background),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'uploading ${(_uploadProgress * 100).toStringAsFixed(1)}%'.toLowerCase(),
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.background,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage!.toLowerCase(),
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ] else if (_videoFile != null) ...[
                    if (_thumbnailUrl == null) ...[
                      Icon(
                        Icons.video_file,
                        size: 32,
                        color: AppColors.background,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        file_path.basename(_videoFile!.path),
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      Text(
                        'tap to change video'.toLowerCase(),
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ] else ...[
                    Icon(
                      Icons.video_library,
                      size: 32,
                      color: AppColors.background,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'select video'.toLowerCase(),
                      style: TextStyle(
                        color: AppColors.background,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    if (!_isCreatingPost) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'create post'.toLowerCase(),
          style: TextStyle(
            color: AppColors.background,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              color: AppColors.background,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'creating post...'.toLowerCase(),
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
            _buildVideoSelector(),
            const SizedBox(height: 16),

            // Form
            if (!_isCreatingPost) ...[
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
                        labelText: 'Title'.toLowerCase(),
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
                        labelText: 'Description'.toLowerCase(),
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
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accent : AppColors.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.accent : AppColors.textSecondary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                color: isSelected ? AppColors.background : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppColors.error.withOpacity(0.1),
                child: Text(
                  _errorMessage!.toLowerCase(),
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 16),
            
            // Upload Button
            if (_videoFile != null && !_isProcessingVideo)
              _buildUploadButton(),
          ],
        ),
      ),
    );
  }
} 