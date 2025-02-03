import 'package:flutter/material.dart';

class VideoFeedScreen extends StatelessWidget {
  const VideoFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReelAI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () {
              // TODO: Implement video upload
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video upload coming soon!')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 10, // Show 10 placeholder items
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sample Video ${index + 1}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This is a placeholder for video content. Upload feature coming soon!',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.remove_red_eye, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('${(index + 1) * 100} views',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(width: 16),
                          Icon(Icons.thumb_up, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('${(index + 1) * 10} likes',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement video upload
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video upload coming soon!')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 