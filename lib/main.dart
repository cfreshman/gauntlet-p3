import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force landscape orientation and set system UI style
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black,
      systemNavigationBarDividerColor: Colors.black,
      statusBarColor: Colors.black,
    ),
  );
  
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.light(
          primary: MinecraftColors.redstone,
          secondary: MinecraftColors.darkRedstone,
          surface: MinecraftColors.lightSandstone,
          background: Colors.transparent,
          error: MinecraftColors.darkRedstone,
        ),
        textTheme: TextTheme(
          displayMedium: TextStyle(color: MinecraftColors.textColor),
          headlineSmall: TextStyle(color: MinecraftColors.textColor),
          bodyLarge: TextStyle(color: MinecraftColors.textColor),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: MinecraftColors.lightSandstone,
          labelStyle: TextStyle(color: MinecraftColors.textColor),
          prefixIconColor: MinecraftColors.darkRedstone,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: MinecraftColors.redstone),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: MinecraftColors.redstone),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(
              color: MinecraftColors.darkRedstone,
              width: 2,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: MinecraftColors.redstone,
            foregroundColor: MinecraftColors.lightSandstone,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: MinecraftColors.darkRedstone,
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(
                  color: MinecraftColors.redstone,
                ),
              ),
            );
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