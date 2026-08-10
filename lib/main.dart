import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memorygame/firebase_options.dart';
import 'package:memorygame/providers/game_provider.dart';
import 'package:memorygame/providers/rps_provider.dart';
import 'package:memorygame/screens/my_app/my_app.dart';
import 'package:memorygame/services/auth_service.dart';
import 'package:memorygame/services/profile_service.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e, st) {
    // The game is fully playable without an account, so a Firebase failure
    // must not prevent the app from starting.
    developer.log(
      'Firebase.initializeApp failed: code=${e.code} message=${e.message}',
      name: 'main',
      error: e,
      stackTrace: st,
    );
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final profileService = ProfileService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => GameProvider()),
        ChangeNotifierProvider(create: (context) => RPSProvider()),
        Provider<ProfileService>.value(value: profileService),
        ChangeNotifierProvider(
          create: (context) => AuthService(profileService: profileService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}