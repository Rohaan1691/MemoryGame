import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:memorygame/network/routes.dart';
import 'package:memorygame/providers/game_provider.dart';
import 'package:memorygame/services/auth_service.dart';
import 'package:memorygame/utils/app_utils.dart';
import 'package:memorygame/utils/custom_audios.dart';
import 'package:memorygame/utils/custom_colors.dart';
import 'package:memorygame/utils/custom_images.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    audioPlayer.play(AssetSource(CustomAudios.opening));
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: black,
      body: body(context, screenSize),
    );
  }

  /// Persistent profile affordance in the top corner.
  ///
  /// Signed in with a photo -> the photo. Signed in without one -> their
  /// initial. Signed out -> a generic person icon, and tapping routes to the
  /// login screen instead of the profile.
  ///
  /// Wrapped in a Consumer so only this button rebuilds when auth state
  /// changes; the surrounding layout is untouched.
  Widget profileButton(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final user = auth.currentUser;
        final signedIn = user != null;
        final photoUrl = user?.photoURL;
        final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
        final name = (user?.displayName ?? '').trim();
        final initial = name.isNotEmpty ? name[0].toUpperCase() : null;

        return InkWell(
          onTap: () {
            audioPlayer.stop();
            AppUtils.pushNamed(
              context,
              signedIn ? Routes.profileScreen : Routes.loginScreen,
            );
          },
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: blue,
              borderRadius: const BorderRadius.all(Radius.circular(15)),
              border: Border.all(color: lightGrey, width: 2),
              image: hasPhoto
                  ? DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasPhoto
                ? null
                : Text(
                    signedIn && initial != null ? initial : '👤',
                    style: TextStyle(
                      color: white,
                      fontSize: signedIn && initial != null ? 22 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget body(BuildContext context, var screenSize){
    return SizedBox(
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
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    alignment: Alignment.center,
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
                SizedBox(height: 50),
                SizedBox(
                  width: screenSize.width/1.5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: green,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            border: Border.all(color: yellow, width: 2),
                          ),
                          child: InkWell(
                            onTap: () {
                              audioPlayer.stop();
                              GameProvider provider = Provider.of<GameProvider>(context, listen: false);
                              provider.setIsVsCpu(false);
                              AppUtils.popAndPushNamed(context, Routes.difficultyScreen);
                            },
                            child: Center(
                              child: Text(
                                'TWO PLAYERS',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 50),
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: blue,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            border: Border.all(color: yellow, width: 2),
                          ),
                          child: InkWell(
                            onTap: () {
                              audioPlayer.stop();
                              GameProvider provider = Provider.of<GameProvider>(context, listen: false);
                              provider.setIsVsCpu(true);
                              AppUtils.popAndPushNamed(context, Routes.difficultyScreen);
                            },
                            child: Center(
                              child: Text(
                                'VS COMPUTER',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Profile / sign-in entry point. Overlaid so the existing centred
          // layout above is unchanged.
          Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topRight,
              child: profileButton(context),
            ),
          ),
        ],
      ),
    );
  }
}

