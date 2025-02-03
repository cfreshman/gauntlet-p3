import 'package:flutter/material.dart';
import 'playlist_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool showVideos = false;  // Default to showing playlists
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // TODO: Show settings menu
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // User info section
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Profile picture
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                // Username
                const Text(
                  '@username',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatColumn('Following', '123'),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.grey[800],
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                    ),
                    _buildStatColumn('Followers', '456'),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.grey[800],
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                    ),
                    _buildStatColumn('Lists', '12'),  // Changed from Likes to Lists
                  ],
                ),
                const SizedBox(height: 16),
                // Edit profile button
                OutlinedButton(
                  onPressed: () {
                    // TODO: Navigate to edit profile
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Edit Profile'),
                ),
                const SizedBox(height: 24),
                // Toggle between Videos and Lists
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildToggleButton('Lists', !showVideos),
                    _buildToggleButton('Videos', showVideos),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          
          // Content grid (either videos or playlists)
          showVideos ? _buildVideoGrid() : _buildPlaylistGrid(),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          showVideos = label == 'Videos';
        });
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: 60,
            color: isSelected ? Colors.white : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2/3,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Row(
                      children: const [
                        Icon(Icons.play_arrow, size: 12),
                        SizedBox(width: 4),
                        Text('1.2K', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaylistGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaylistDetailScreen(playlistId: index.toString()),
                    ),
                  );
                },
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // First video thumbnail
                      Container(
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            size: 32,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                      // Playlist info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Playlist ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(index + 1) * 5} videos',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Arrow indicator
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Icon(
                          Icons.chevron_right,
                          color: Colors.grey[600],
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
    );
  }
} 