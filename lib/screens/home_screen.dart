import 'package:flutter/material.dart';
import 'package:reel_ai/screens/video_feed_screen.dart';
import 'package:reel_ai/screens/search_screen.dart';
import 'package:reel_ai/screens/profile_screen.dart';
import 'package:reel_ai/screens/upload_video_screen.dart';
import 'package:reel_ai/screens/subscription_feed_screen.dart';
import '../theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static void navigateToSearch(BuildContext context, String tag) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    if (state != null) {
      state._navigateToSearch(tag);
    }
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;
  String? _searchTag;

  List<Widget> get _screens => [
    const UploadVideoScreen(),
    const VideoFeedScreen(),
    const SubscriptionFeedScreen(),
    SearchScreen(initialTag: _searchTag),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToSearch(String tag) {
    setState(() {
      _searchTag = tag;
      _selectedIndex = 3; // Index of SearchScreen
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Background that extends edge to edge
            Container(color: AppColors.background),
            
            // Content that respects safe area
            SafeArea(
              bottom: false,
              child: Row(
                children: [
                  // Left side navigation rail
                  NavigationRail(
                    backgroundColor: Colors.transparent,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onItemTapped,
                    labelType: NavigationRailLabelType.all,
                    useIndicator: true,
                    minWidth: 60,
                    minExtendedWidth: 60,
                    groupAlignment: 0,
                    indicatorColor: AppColors.accent,
                    selectedIconTheme: IconThemeData(
                      color: AppColors.background,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: AppColors.accent.withOpacity(0.7),
                    ),
                    selectedLabelTextStyle: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelTextStyle: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.7),
                    ),
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: IconButton(
                            icon: Icon(Icons.logout, color: AppColors.accent.withOpacity(0.7)),
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                            },
                          ),
                        ),
                      ),
                    ),
                    destinations: const <NavigationRailDestination>[
                      NavigationRailDestination(
                        icon: Icon(Icons.upload_outlined),
                        selectedIcon: Icon(Icons.upload),
                        label: SizedBox.shrink(),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.play_circle_outline),
                        selectedIcon: Icon(Icons.play_circle_fill),
                        label: Text('watch'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.subscriptions_outlined),
                        selectedIcon: Icon(Icons.subscriptions),
                        label: Text('subs'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.search_outlined),
                        selectedIcon: Icon(Icons.search),
                        label: SizedBox.shrink(),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: SizedBox.shrink(),
                      ),
                    ],
                  ),
                  
                  // Vertical divider
                  VerticalDivider(
                    thickness: 1,
                    width: 1,
                    color: AppColors.accent.withOpacity(0.2),
                  ),
                  
                  // Main content
                  Expanded(
                    child: _screens[_selectedIndex],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 