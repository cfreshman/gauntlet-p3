import 'package:flutter/material.dart';
import 'package:reel_ai/screens/video_feed_screen.dart';
import 'package:reel_ai/screens/search_screen.dart';
import 'package:reel_ai/screens/profile_screen.dart';
import 'package:reel_ai/screens/upload_video_screen.dart';
import '../theme/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;

  static const List<Widget> _screens = <Widget>[
    UploadVideoScreen(),
    VideoFeedScreen(),
    SearchScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Row(
            children: [
              // Left side navigation rail
              NavigationRail(
                backgroundColor: MinecraftColors.lightSandstone,
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                labelType: NavigationRailLabelType.all,
                useIndicator: true,
                indicatorColor: MinecraftColors.darkRedstone,
                selectedIconTheme: IconThemeData(
                  color: MinecraftColors.lightSandstone,
                ),
                unselectedIconTheme: IconThemeData(
                  color: MinecraftColors.darkRedstone.withOpacity(0.7),
                ),
                selectedLabelTextStyle: TextStyle(
                  color: MinecraftColors.darkRedstone,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: MinecraftColors.darkRedstone.withOpacity(0.7),
                ),
                destinations: const <NavigationRailDestination>[
                  NavigationRailDestination(
                    icon: Icon(Icons.upload_outlined),
                    selectedIcon: Icon(Icons.upload),
                    label: Text('Upload'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.play_circle_outline),
                    selectedIcon: Icon(Icons.play_circle_fill),
                    label: Text('Watch'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.search_outlined),
                    selectedIcon: Icon(Icons.search),
                    label: Text('Search'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('Profile'),
                  ),
                ],
              ),
              
              // Vertical divider
              VerticalDivider(
                thickness: 1,
                width: 1,
                color: MinecraftColors.darkRedstone.withOpacity(0.2),
              ),
              
              // Main content
              Expanded(
                child: Container(
                  color: MinecraftColors.sandstone,
                  child: _screens[_selectedIndex],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 