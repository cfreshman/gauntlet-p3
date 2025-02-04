import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../constants/tags.dart';

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
              color: MinecraftColors.darkRedstone.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '#$tag',
              style: TextStyle(
                color: MinecraftColors.redstone,
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
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search videos...',
              prefixIcon: Icon(Icons.search, color: MinecraftColors.darkRedstone),
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
                  color: MinecraftColors.darkRedstone.withOpacity(0.1),
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
                        color: MinecraftColors.redstone,
                      ),
                    ),
                    // Duration overlay
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '12:34',
                          style: TextStyle(
                            fontSize: 12,
                            color: MinecraftColors.lightSandstone,
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
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 12,
                              color: MinecraftColors.lightSandstone,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '1.2K',
                              style: TextStyle(
                                fontSize: 12,
                                color: MinecraftColors.lightSandstone,
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
    );
  }
} 