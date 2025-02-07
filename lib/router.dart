import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/standalone_video_screen.dart';
import 'screens/playlist_detail_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/upload_video_screen.dart';
import 'screens/video_feed_screen.dart';
import 'screens/subscription_feed_screen.dart';
import 'screens/search_screen.dart';
import 'services/video_service.dart';
import 'models/video.dart';
import 'widgets/scaffold_with_navigation_rail.dart';
import 'theme/colors.dart';

final _auth = FirebaseAuth.instance;
final _videoService = VideoService();

// Create a listenable to refresh router on auth state changes
final _authStateListenable = GoRouterRefreshStream(_auth.authStateChanges());

final router = GoRouter(
  initialLocation: '/watch',
  refreshListenable: _authStateListenable,
  redirect: (context, state) {
    final isLoggedIn = _auth.currentUser != null;
    final isAuthRoute = state.matchedLocation == '/login';
    final isVideoRoute = state.matchedLocation.startsWith('/video/');

    // Allow video routes without auth
    if (isVideoRoute) {
      return null;
    }

    if (!isLoggedIn && !isAuthRoute) {
      // Save the attempted path to redirect back after login
      return '/login?from=${state.matchedLocation}';
    }

    if (isLoggedIn && isAuthRoute) {
      // If we have a saved path, go there, otherwise go to watch feed
      final fromPath = state.uri.queryParameters['from'];
      return fromPath ?? '/watch';
    }

    return null;
  },
  routes: [
    // Auth
    GoRoute(
      path: '/login',
      builder: (context, state) => const AuthScreen(),
    ),
    
    // Main navigation shell
    StatefulShellRoute(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavigationRail(
          navigationShell: navigationShell,
        );
      },
      navigatorContainerBuilder: (context, navigationShell, children) {
        return children[navigationShell.currentIndex];
      },
      branches: [
        // Upload branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/upload',
              builder: (context, state) => const UploadVideoScreen(),
            ),
          ],
        ),
        // Watch feed branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/watch',
              builder: (context, state) => const VideoFeedScreen(),
            ),
          ],
        ),
        // Subscriptions feed branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/subs',
              builder: (context, state) => const SubscriptionFeedScreen(),
            ),
          ],
        ),
        // Search branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) {
                final query = state.uri.queryParameters['q'];
                final tags = state.uri.queryParameters['tags']?.split(',');
                return SearchScreen(initialQuery: query, initialTag: tags?.firstOrNull);
              },
            ),
          ],
        ),
        // Profile branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return const VideoFeedScreen();
                return ProfileScreen(userId: user.uid);
              },
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final userId = state.pathParameters['id']!;
                    return ProfileScreen(userId: userId);
                  },
                  routes: [
                    GoRoute(
                      path: 'settings',
                      builder: (context, state) {
                        final userId = state.pathParameters['id']!;
                        if (userId != _auth.currentUser?.uid) {
                          return const VideoFeedScreen();
                        }
                        return const EditProfileScreen();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // Non-shell routes
    GoRoute(
      path: '/video/:videoId',
      builder: (context, state) {
        final videoId = state.pathParameters['videoId']!;
        return FutureBuilder(
          future: _videoService.getVideoById(videoId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            final video = snapshot.data;
            if (video == null) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: Text(
                    'video not found',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              );
            }
            
            return StandaloneVideoScreen(
              videos: [video],
              initialIndex: 0,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/playlist',
      builder: (context, state) {
        final playlistId = state.uri.queryParameters['list'];
        if (playlistId == null) return const VideoFeedScreen();
        return PlaylistDetailScreen(playlistId: playlistId);
      },
    ),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
} 