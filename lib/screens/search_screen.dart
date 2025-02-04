import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../constants/tags.dart';
import '../models/video.dart';
import '../extensions/string_extensions.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  Widget _buildTagChip(String tag, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '#$tag'.lowercase,
              style: TextStyle(
                color: AppColors.accent,
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
                children: MinecraftTags.all.map((tag) => _buildTagChip(
                  tag,
                  onTap: () {
                    // TODO: Implement tag selection
                  },
                )).toList(),
              ),
            ),
          ),

          // Video grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 16 / 9, // Minecraft videos are landscape
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail
                      Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 32,
                          color: AppColors.accent,
                        ),
                      ),
                      // Duration overlay
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '12:34',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                      // View count overlay
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 12,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '1.2k views'.lowercase,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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