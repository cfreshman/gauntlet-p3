import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../constants/tags.dart';
import '../models/video.dart';
import '../extensions/string_extensions.dart';
import '../services/video_service.dart';
import '../widgets/video_preview.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialTag;
  
  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialTag,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _videoService = VideoService();
  final _searchController = TextEditingController();
  List<Video> _videos = [];
  String? _selectedTag;
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedTag = widget.initialTag;
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    _loadVideos();
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always reset state when navigating through nav rail
    if (widget.initialTag != oldWidget.initialTag) {
      setState(() {
        _selectedTag = widget.initialTag;
        // Clear search if we're clearing tags
        if (widget.initialTag == null) {
          _searchController.text = '';
        }
      });
      _loadVideos();
    }
    // Update search if initialQuery changes
    if (widget.initialQuery != oldWidget.initialQuery) {
      _searchController.text = widget.initialQuery ?? '';
      _loadVideos();
    }
  }

  void _updateUrl() {
    final queryParams = <String, String>{};
    if (_searchController.text.isNotEmpty) {
      queryParams['q'] = _searchController.text;
    }
    if (_selectedTag != null) {
      queryParams['tags'] = _selectedTag!;
    }
    
    context.go(
      '/search${queryParams.isEmpty ? '' : '?${Uri(queryParameters: queryParams).query}'}',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      final videos = await _videoService.searchVideos(
        query: _searchController.text,
        tag: _selectedTag,
      );
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading videos: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _updateUrl();
      _loadVideos();
    });
  }

  void _onTagSelected(String tag) {
    setState(() {
      _selectedTag = _selectedTag == tag ? null : tag;
    });
    _updateUrl();
    _loadVideos();
  }

  Widget _buildTagChip(String tag) {
    final isSelected = tag == _selectedTag;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTagSelected(tag),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected 
                ? AppColors.accent 
                : AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '#$tag'.lowercase,
              style: TextStyle(
                color: isSelected ? AppColors.background : AppColors.accent,
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
      ),
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search videos...'.lowercase,
                prefixIcon: Icon(Icons.search, color: AppColors.textPrimary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // Trending hashtags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: MinecraftTags.all.map(_buildTagChip).toList(),
              ),
            ),
          ),

          // Video grid
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                  )
                : _videos.isEmpty
                    ? Center(
                        child: Text(
                          'No videos found'.lowercase,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 16 / 9,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          final video = _videos[index];
                          return SizedBox(
                            height: 180,
                            child: VideoPreview(
                              video: video,
                              showTitle: true,
                              showCreator: false,
                              videos: _videos,
                              currentIndex: index,
                              showTimeAgo: true,
                              showDuration: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 