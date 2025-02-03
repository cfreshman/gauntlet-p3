import 'package:flutter/material.dart';

class VideoFeedScreen extends StatelessWidget {
  const VideoFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Watch',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemBuilder: (context, index) {
          return VideoCard(index: index);
        },
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  final int index;

  const VideoCard({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Placeholder for video
        Container(
          color: Colors.grey[900],
          child: Center(
            child: Icon(
              Icons.play_circle_outline,
              size: 84,
              color: Colors.grey[400],
            ),
          ),
        ),
        
        // Video info overlay
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@creator_name',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Video caption #hashtag',
                style: TextStyle(
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
        ),
        
        // Right side action buttons
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              _buildActionButton(Icons.favorite_border, '1.2K'),
              _buildActionButton(Icons.comment_outlined, '234'),
              _buildActionButton(Icons.share_outlined, '56'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 4),
          Text(count),
        ],
      ),
    );
  }
} 