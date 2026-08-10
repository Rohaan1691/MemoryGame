import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memorygame/network/routes.dart';
import 'package:memorygame/services/auth_service.dart';
import 'package:memorygame/utils/app_utils.dart';
import 'package:memorygame/utils/custom_colors.dart';
import 'package:memorygame/utils/custom_images.dart';
import 'package:provider/provider.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  StreamSubscription<User?>? _authSub;
  User? _user;

  @override
  void initState() {
    super.initState();
    AppUtils.statusBarNavigationBar(0, Brightness.dark);

    // Resolve auth state during the existing 3 second splash. The wait itself
    // is unchanged; only the destination now depends on the result.
    final auth = context.read<AuthService>();
    unawaited(auth.init());
    _authSub = auth.authStateChanges().listen(
      (user) => _user = user,
      onError: (Object error, StackTrace stack) {
        developer.log(
          'authStateChanges error during splash',
          name: 'Splash',
          error: error,
          stackTrace: stack,
        );
      },
    );

    Future.delayed(Duration(seconds: 3), moveToNextScreen);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: black,
      body: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          children: [
            Center(
              child: Image.asset(
                CustomImages.gameBG,
                width: screenSize.width,
                height: screenSize.height,
                fit: BoxFit.cover,
              ),
            ),Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    child: Image.asset(
                      CustomImages.flagLogo,
                      width: 200,
                      height: 200,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            ),
          ]
        ),
      ),
    );
  }

  void moveToNextScreen() {
    if (!mounted) return;
    AppUtils.popAndPushNamed(
      context,
      _user != null ? Routes.main : Routes.loginScreen,
    );
  }
}
