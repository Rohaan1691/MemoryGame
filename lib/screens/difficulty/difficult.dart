import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:memorygame/network/routes.dart';
import 'package:memorygame/providers/game_provider.dart';
import 'package:memorygame/services/profile_service.dart';
import 'package:memorygame/utils/app_utils.dart';
import 'package:memorygame/utils/constants.dart';
import 'package:memorygame/utils/custom_audios.dart';
import 'package:memorygame/utils/custom_colors.dart';
import 'package:memorygame/utils/custom_images.dart';
import 'package:memorygame/utils/custom_text_icons.dart';
import 'package:provider/provider.dart';

class Difficulty extends StatefulWidget {
  const Difficulty({super.key});

  @override
  State<Difficulty> createState() => _DifficultyState();
}

class _DifficultyState extends State<Difficulty> {
  /// Ends any run on a different difficulty, so the profile's progress bar
  /// resets as soon as the player switches rather than lagging behind until
  /// their next game finishes.
  ///
  /// Additive: called alongside the existing setDifficultyMode calls and never
  /// awaited, so it cannot delay or block starting a game.
  void _endRunsOnOtherDifficulties(BuildContext context, int difficultyMode) {
    final provider = Provider.of<GameProvider>(context, listen: false);
    final profileService = Provider.of<ProfileService>(context, listen: false);
    unawaited(
      profileService.resetStreaksExcept(
        isVsCpu: provider.isVsCpu,
        difficulty: Difficulties.fromMode(difficultyMode),
      ),
    );
  }



  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;

    return Scaffold(backgroundColor: black, body: body(context, screenSize));
  }

  Widget body(BuildContext context, var screenSize) {
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
            child: InkWell(
              onTap: (){
                AppUtils.popAndPushNamed(context, Routes.main);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: blue,
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                  border: Border.all(color: lightGrey, width: 2),
                ),
                child: Icon(Icons.arrow_back, color: white, size: 25,),
              ),
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
                  width: screenSize.width / 1.5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      actionButton(
                        green,
                        white,
                        CustomTextIcons.easy,
                        'EASY',
                        () async {
                          GameProvider provider = Provider.of<GameProvider>(context, listen: false);
                          provider.setDifficultyMode(1);
                          _endRunsOnOtherDifficulties(context, 1);
                          if (provider.isSoundOn) {
                            await _audioPlayer.stop();
                            await _audioPlayer.play(AssetSource(CustomAudios.funClick));
                            await Future.delayed(Duration(milliseconds: 300));
                          }
                          AppUtils.popAndPushNamed(context, Routes.gameScreen);
                        },
                      ),
                      const SizedBox(width: 10),
                      actionButton(
                        yellow,
                        white,
                        CustomTextIcons.medium,
                        'MEDIUM',
                        () async {
                          GameProvider provider = Provider.of<GameProvider>(context, listen: false);
                          provider.setDifficultyMode(2);
                          _endRunsOnOtherDifficulties(context, 2);
                          if (provider.isSoundOn) {
                            await _audioPlayer.stop();
                            await _audioPlayer.play(AssetSource(CustomAudios.funClick));
                            await Future.delayed(Duration(milliseconds: 300));
                          }
                          AppUtils.popAndPushNamed(context, Routes.gameScreen);
                        },
                      ),
                      const SizedBox(width: 10),
                      actionButton(
                        lightRed,
                        white,
                        CustomTextIcons.hard,
                        'HARD',
                        () async {
                          GameProvider provider = Provider.of<GameProvider>(context, listen: false);
                          provider.setDifficultyMode(3);
                          _endRunsOnOtherDifficulties(context, 3);
                          if (provider.isSoundOn) {
                            await _audioPlayer.stop();
                            await _audioPlayer.play(AssetSource(CustomAudios.funClick));
                            await Future.delayed(Duration(milliseconds: 300));
                          }
                          AppUtils.popAndPushNamed(context, Routes.gameScreen);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget actionButton(
    Color bgColor,
    Color textColor,
    String icon,
    String title,
    Function onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          onTap();
        },
        child: Container(
          height: 60,
          padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            border: Border.all(color: bgColor, width: 4),
          ),
          child: Center(
            child: Text(
              "$icon  $title",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: bgColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
