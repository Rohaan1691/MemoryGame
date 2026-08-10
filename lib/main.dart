import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memorygame/providers/game_provider.dart';
import 'package:memorygame/providers/rps_provider.dart';
import 'package:memorygame/screens/my_app/my_app.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => GameProvider()),
        ChangeNotifierProvider(create: (context) => RPSProvider()),
      ],
      child: const MyApp(),
    ),
  );
}