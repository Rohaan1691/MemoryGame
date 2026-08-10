import 'package:flutter/material.dart';
import 'package:memorygame/network/routes.dart';
import 'package:memorygame/utils/app_utils.dart';
import 'package:memorygame/utils/custom_colors.dart';
import 'package:memorygame/utils/custom_images.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    AppUtils.statusBarNavigationBar(0, Brightness.dark);
    Future.delayed(Duration(seconds: 3), moveToMainScreen);
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

  void moveToMainScreen() {
    AppUtils.popAndPushNamed(context, Routes.main);
  }
}
