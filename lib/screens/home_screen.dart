import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reel_ai/screens/video_feed_screen.dart';
import 'package:reel_ai/screens/search_screen.dart';
import 'package:reel_ai/screens/profile_screen.dart';
import 'package:reel_ai/screens/upload_video_screen.dart';
import 'package:reel_ai/screens/subscription_feed_screen.dart';
import '../theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  final String? initialQuery;
  final List<String>? initialTags;
  final StatefulNavigationShell navigationShell;
  
  const HomeScreen({
    super.key, 
    this.initialQuery,
    this.initialTags,
    required this.navigationShell,
  });

  static void navigateToSearch(BuildContext context, String tag) {
    final shell = context.findAncestorWidgetOfExactType<StatefulNavigationShell>();
    if (shell != null) {
      shell.goBranch(3); // Switch to search tab
      context.go('/search?tags=$tag');
    }
  }

  static void navigateToProfile(BuildContext context, String userId) {
    context.go('/profile/$userId');
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  void _onItemTapped(int index) {
    widget.navigationShell.goBranch(index);
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
                    selectedIndex: widget.navigationShell.currentIndex,
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
                    child: widget.navigationShell,
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