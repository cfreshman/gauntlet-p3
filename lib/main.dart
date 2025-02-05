import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';
import 'theme/colors.dart';
import 'widgets/loading_indicator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase first
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set up system UI for edge-to-edge content
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TikBlok',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Menlo',
        colorScheme: ColorScheme.dark(
          background: AppColors.background,
          primary: AppColors.accent,
          onPrimary: AppColors.background,
          secondary: AppColors.accentLight,
          onSecondary: AppColors.background,
          surface: AppColors.cardBackground,
          onSurface: AppColors.textPrimary,
          error: AppColors.error,
          onError: AppColors.textPrimary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        cardTheme: CardTheme(
          color: AppColors.cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Menlo',
            color: AppColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          displayMedium: TextStyle(
            fontFamily: 'Menlo',
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Menlo',
            color: AppColors.textPrimary,
            fontSize: 16,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Menlo',
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Menlo',
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Menlo',
            fontSize: 14,
            height: 1.5,
            letterSpacing: 0.5,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputBackground,
          labelStyle: TextStyle(
            fontFamily: 'Menlo',
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          hintStyle: TextStyle(
            fontFamily: 'Menlo',
            color: AppColors.textSecondary.withOpacity(0.7),
            fontSize: 14,
          ),
          prefixIconColor: AppColors.textSecondary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.accent,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.error,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.error,
              width: 2,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.background,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.cardBackground,
          contentTextStyle: TextStyle(
            fontFamily: 'Menlo',
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        dividerTheme: DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }
          
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          
          return const AuthScreen();
        },
      ),
    );
  }
}