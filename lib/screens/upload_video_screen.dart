import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/video_service.dart';
import '../theme/colors.dart';
import '../constants/tags.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _videoService = VideoService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  
  File? _videoFile;
  VideoPlayerController? _videoController;
  List<String> _selectedTags = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  // Use the centralized tag list
  List<String> get _suggestedTags => MinecraftTags.all
      .where((tag) => !_selectedTags.contains(tag))
      .toList();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        _videoController?.dispose();
        final videoFile = File(video.path);
        
        // Initialize video controller for preview
        final controller = VideoPlayerController.file(videoFile);
        await controller.initialize();
        
        setState(() {
          _videoFile = videoFile;
          _videoController = controller;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick video: $e';
      });
    }
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
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
      _errorMessage = null;
    });

    try {
      await _videoService.uploadVideo(
        _videoFile!,
        title: _titleController.text,
        description: _descriptionController.text,
        tags: _selectedTags,
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
        // Reset the form
        setState(() {
          _videoFile = null;
          _videoController?.dispose();
          _videoController = null;
          _titleController.clear();
          _descriptionController.clear();
          _selectedTags.clear();
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildTagChip(String tag) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: MinecraftColors.darkRedstone.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag,
              style: TextStyle(
                color: MinecraftColors.redstone,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _removeTag(tag),
              borderRadius: BorderRadius.circular(12),
              child: Icon(
                Icons.close,
                size: 18,
                color: MinecraftColors.redstone,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedTagChip(String tag) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isUploading ? null : () => _addTag(tag),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: MinecraftColors.darkRedstone.withOpacity(_isUploading ? 0.08 : 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tag,
              style: TextStyle(
                color: MinecraftColors.redstone.withOpacity(_isUploading ? 0.5 : 1.0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Video Preview/Picker
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _videoController != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),
                              IconButton(
                                icon: Icon(
                                  _videoController!.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _videoController!.value.isPlaying
                                        ? _videoController!.pause()
                                        : _videoController!.play();
                                  });
                                },
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: IconButton(
                            icon: const Icon(Icons.video_library),
                            onPressed: _isUploading ? null : _pickVideo,
                            iconSize: 48,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                  enabled: !_isUploading,
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  enabled: !_isUploading,
                ),
                const SizedBox(height: 16),

                // Tags
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Tags'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _selectedTags
                          .map((tag) => _buildTagChip(tag))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tagController,
                            decoration: const InputDecoration(
                              hintText: 'Add a tag',
                              border: OutlineInputBorder(),
                            ),
                            onFieldSubmitted: _addTag,
                            enabled: !_isUploading,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isUploading
                              ? null
                              : () => _addTag(_tagController.text),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _suggestedTags
                          .map((tag) => _buildSuggestedTagChip(tag))
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],

                // Upload progress
                if (_isUploading) ...[
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 16),
                ],

                // Upload button
                ElevatedButton(
                  onPressed: _isUploading ? null : _uploadVideo,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isUploading
                      ? const Text('Uploading...')
                      : const Text('Upload Video'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 