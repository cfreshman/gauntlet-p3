import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool showVideos = false;  // Default to showing playlists
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left side - User info
        Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: MinecraftColors.darkRedstone.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: MinecraftColors.redstone,
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: MinecraftColors.lightSandstone,
                ),
              ),
              const SizedBox(height: 16),
              // Username
              const Text(
                '@minecraft_player',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Bio
              Text(
                'Minecraft content creator',
                style: TextStyle(
                  color: MinecraftColors.darkRedstone,
                ),
              ),
              const SizedBox(height: 16),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('Following', '123'),
                  _buildStatColumn('Followers', '1.2K'),
                  _buildStatColumn('Likes', '12.3K'),
                ],
              ),
              const SizedBox(height: 16),
              // Edit Profile Button
              FilledButton.tonal(
                onPressed: () {
                  // TODO: Implement edit profile
                },
                child: const Text('Edit Profile'),
              ),
            ],
          ),
        ),

        // Right side - Content
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: MinecraftColors.darkRedstone.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // Playlist thumbnail
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: MinecraftColors.darkRedstone.withOpacity(0.2),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(8),
                          ),
                        ),
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 32,
                          color: MinecraftColors.redstone,
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
                                color: MinecraftColors.darkRedstone,
                                fontSize: 14,
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
          style: TextStyle(
            color: MinecraftColors.darkRedstone,
          ),
        ),
      ],
    );
  }
} 