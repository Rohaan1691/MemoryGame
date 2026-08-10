import 'package:flutter/material.dart';
import 'package:memorygame/network/routes.dart';
import 'package:memorygame/screens/difficulty/difficult.dart';
import 'package:memorygame/screens/game_screen/game_screen.dart';
import 'package:memorygame/screens/login_screen.dart';
import 'package:memorygame/screens/main_screen/main_screen.dart';
import 'package:memorygame/screens/profile_screen.dart';
import 'package:memorygame/screens/rps/rps.dart';
import 'package:memorygame/screens/splash/splash.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MultiMatch Flag Challenge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(cardColor: Colors.white),
      onGenerateRoute: (settings) {
        if (settings.name == Routes.splash) {
          return MaterialPageRoute(
            builder: (context) => const Splash(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        } else if (settings.name == Routes.main) {
          return MaterialPageRoute(
            builder: (context) => const MainScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        } else if (settings.name == Routes.difficultyScreen) {
          return MaterialPageRoute(
            builder: (context) => const Difficulty(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        } else if (settings.name == Routes.gameScreen) {
          return MaterialPageRoute(
            builder: (context) => const GameScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        } else if (settings.name == Routes.loginScreen) {
          return MaterialPageRoute(
            builder: (context) => const LoginScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        } else if (settings.name == Routes.profileScreen) {
          return MaterialPageRoute(
            builder: (context) => const ProfileScreen(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        } else {
          return MaterialPageRoute(
            builder: (context) => const Splash(),
            settings: RouteSettings(arguments: settings.arguments),
          );
        }
      },
      home: const Splash(),
    );
  }
}
