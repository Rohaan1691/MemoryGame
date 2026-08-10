import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:memorygame/network/routes.dart';
import 'package:memorygame/providers/game_provider.dart';
import 'package:memorygame/providers/rps_provider.dart';
import 'package:memorygame/utils/app_utils.dart';
import 'package:memorygame/utils/constants.dart';
import 'package:memorygame/utils/custom_audios.dart';
import 'package:memorygame/utils/custom_colors.dart';
import 'package:memorygame/utils/custom_images.dart';
import 'package:memorygame/utils/custom_text_icons.dart';
import 'package:provider/provider.dart';

class Rps extends StatelessWidget {
  const Rps({super.key});

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;

    GameProvider gameProvider = Provider.of<GameProvider>(
      context,
      listen: false,
    );
    if (gameProvider.isVsCpu) {
      AppUtils.playSound(CustomAudios.lockinChime, context);
      shufflePlayer2Choice(context);
    }

    return Scaffold(
      backgroundColor: black,
      body: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          children: [
            Center(
              child: Image.asset(
                CustomImages.rpsBG,
                width: screenSize.width,
                height: screenSize.height,
                fit: BoxFit.cover,
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "⚡ TIEBREAKER ⚡",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: yellow,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Flags equal. Memories equal. One throw decides it. Lock in your move!",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Selector2<RPSProvider, GameProvider, Map<String, dynamic>>(
                    selector: (context, rpsProvider, gameProvider) => {
                      'result': rpsProvider.result,
                      'player1': rpsProvider.player1,
                      'isPlayer1Shuffling': rpsProvider.isPlayer1Shuffling,
                      'remainingSeconds': rpsProvider.remainingSeconds,
                      'player2': rpsProvider.player2,
                      'isPlayer2Shuffling': rpsProvider.isPlayer2Shuffling,
                      'timer': rpsProvider.timer,
                      'isVsCpu': gameProvider.isVsCpu,
                    },
                    builder: (context, data, _) {
                      final String result = data['result'];
                      final String player1 = data['player1'];
                      final bool isPlayer1Shuffling =
                          data['isPlayer1Shuffling'];
                      final int remainingSeconds = data['remainingSeconds'];
                      final String player2 = data['player2'];
                      final bool isPlayer2Shuffling =
                          data['isPlayer2Shuffling'];
                      final Timer? timer = data['timer'];
                      final bool isVsCpu = data['isVsCpu'];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.fromLTRB(40, 20, 40, 20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: result.contains("Player1")
                                    ? yellow
                                    : result.isEmpty
                                    ? cyan
                                    : grey.withOpacity(0.3),
                                width: result.contains("Player1") ? 6 : 4,
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "PLAYER 1",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color:
                                        result.isEmpty ||
                                            (result.isNotEmpty &&
                                                result.contains("Player1"))
                                        ? cyan
                                        : grey.withOpacity(0.3),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  decoration: BoxDecoration(
                                    color: blackTransparent,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  child: DottedBorder(
                                    options: RoundedRectDottedBorderOptions(
                                      dashPattern: [5, 5],
                                      strokeWidth: 2,
                                      radius: Radius.circular(10),
                                      color:
                                          result.isNotEmpty &&
                                              result.contains("Player1")
                                          ? grey
                                          : grey.withOpacity(0.3),
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 100,
                                          ),
                                          transitionBuilder:
                                              (child, animation) {
                                                return ScaleTransition(
                                                  scale: animation,
                                                  child: child,
                                                );
                                              },
                                          child: Text(
                                            player1,
                                            key: ValueKey(player1),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: grey,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 40,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  isPlayer1Shuffling || result.isNotEmpty
                                      ? "🔒 LOCKED"
                                      : "Waiting...",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color:
                                        isPlayer1Shuffling || result.isNotEmpty
                                        ? result.contains("Player1")
                                              ? green
                                              : green.withOpacity(0.3)
                                        : grey,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                (result.isEmpty || result.contains("Draw")) &&
                                        !isPlayer1Shuffling
                                    ? InkWell(
                                        onTap:
                                            isPlayer1Shuffling ||
                                                (result.isNotEmpty &&
                                                    result != "Draw")
                                            ? null
                                            : () {
                                                AppUtils.playSound(
                                                  CustomAudios.lockinChime,
                                                  context,
                                                );
                                                shufflePlayer1Choice(context);
                                              },
                                        child: Container(
                                          width: 110,
                                          height: 40,
                                          padding: EdgeInsets.fromLTRB(
                                            10,
                                            5,
                                            10,
                                            5,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: isPlayer1Shuffling
                                                  ? [
                                                      Color(0xff717171),
                                                      Color(0xff919090),
                                                    ]
                                                  : [
                                                      Color(0xffA66B00),
                                                      Color(0xffF6BC25),
                                                    ],
                                            ),
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(30),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              isPlayer1Shuffling
                                                  ? "🔒 LOCKED"
                                                  : result.isEmpty ||
                                                        result == "Draw"
                                                  ? "🔒 LOCK IN"
                                                  : "🔒 LOCKED",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: black,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        "LOCKED IN",
                                        style: TextStyle(
                                          fontWeight: FontWeight.normal,
                                          fontSize: 13,
                                          color: yellow,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 30),
                          Text(
                            timer != null && timer.isActive
                                ? remainingSeconds.toString()
                                : "VS",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 50,
                              color: timer != null && timer.isActive
                                  ? yellow
                                  : Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 30),
                          Container(
                            padding: EdgeInsets.fromLTRB(40, 20, 40, 20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: result.contains("Player2")
                                    ? yellow
                                    : result.isEmpty
                                    ? pink
                                    : result.contains("Player2")
                                    ? grey
                                    : grey.withOpacity(0.3),
                                width: result.contains("Player2") ? 6 : 4,
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  isVsCpu ? "CPU" : "PLAYER 2",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color:
                                        result.isEmpty ||
                                            (result.isNotEmpty &&
                                                result.contains("Player2"))
                                        ? pink
                                        : grey.withOpacity(0.3),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  decoration: BoxDecoration(
                                    color: blackTransparent,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  child: DottedBorder(
                                    options: RoundedRectDottedBorderOptions(
                                      dashPattern: [5, 5],
                                      strokeWidth: 2,
                                      radius: Radius.circular(10),
                                      color: grey,
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          player2,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 40,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  isPlayer2Shuffling || result.isNotEmpty
                                      ? "🔒 LOCKED"
                                      : "Waiting...",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color:
                                        isPlayer2Shuffling || result.isNotEmpty
                                        ? result.contains("Player2")
                                              ? green
                                              : green.withOpacity(0.3)
                                        : grey,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                (result.isEmpty || result.contains("Draw")) &&
                                        !isPlayer2Shuffling
                                    ? InkWell(
                                        onTap:
                                            isPlayer2Shuffling ||
                                                (result.isNotEmpty &&
                                                    result != "Draw")
                                            ? null
                                            : () {
                                                AppUtils.playSound(
                                                  CustomAudios.lockinChime,
                                                  context,
                                                );
                                                shufflePlayer2Choice(context);
                                              },
                                        child: Container(
                                          width: 110,
                                          height: 40,
                                          padding: EdgeInsets.fromLTRB(
                                            10,
                                            5,
                                            10,
                                            5,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: isPlayer2Shuffling
                                                  ? [
                                                      Color(0xff717171),
                                                      Color(0xff919090),
                                                    ]
                                                  : [
                                                      Color(0xffA66B00),
                                                      Color(0xffF6BC25),
                                                    ],
                                            ),
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(30),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              isPlayer2Shuffling
                                                  ? "🔒 LOCKED"
                                                  : result.isEmpty ||
                                                        result == "Draw"
                                                  ? "🔒 LOCK IN"
                                                  : "🔒 LOCKED",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: black,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        "LOCKED IN",
                                        style: TextStyle(
                                          fontWeight: FontWeight.normal,
                                          fontSize: 13,
                                          color: yellow,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Selector2<RPSProvider, GameProvider, Map<String, dynamic>>(
                    selector: (context, rpsProvider, gameProvider) => {
                      'result': rpsProvider.result,
                      'player1': rpsProvider.player1,
                      'player2': rpsProvider.player2,
                      'isPlayer1Shuffling': rpsProvider.isPlayer1Shuffling,
                      'isPlayer2Shuffling': rpsProvider.isPlayer2Shuffling,
                      'isVsCpu': gameProvider.isVsCpu,
                    },
                    builder: (context, data, _) {
                      final String result = data['result'];
                      final String player1 = data['player1'];
                      final String player2 = data['player2'];
                      final bool isPlayer1Shuffling =
                          data['isPlayer1Shuffling'];
                      final bool isPlayer2Shuffling =
                          data['isPlayer2Shuffling'];
                      final bool isVsCpu = data['isVsCpu'];
                      final String res = result.contains("Draw")
                          ? "$player1 MEETS $player2 - DEAD HEAT! REROLL!"
                          : getFinalResult(player1, player2);
                      return !isPlayer1Shuffling && !isPlayer2Shuffling
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (result.isNotEmpty)
                                  Text(
                                    result.contains("Draw")
                                        ? res
                                        : "$res - ${result.contains("Player1")
                                              ? "Player 1"
                                              : isVsCpu
                                              ? "CPU"
                                              : "Player 2"} TAKES IT!",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: white,
                                    ),
                                  ),
                                if (!result.contains("Draw") &&
                                    result.isNotEmpty) ...[
                                  SizedBox(height: 10),
                                  InkWell(
                                    onTap: () {
                                      resetRPS(context);
                                      AppUtils.pop(context);
                                    },
                                    child: Container(
                                      width: 220,
                                      height: 40,
                                      padding: EdgeInsets.fromLTRB(
                                        10,
                                        5,
                                        10,
                                        5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: white,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(30),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          "⚡ CROWN THE WINNER",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: black,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> shufflePlayer1Choice(BuildContext context) async {
    RPSProvider provider = Provider.of<RPSProvider>(context, listen: false);
    if (provider.isPlayer1Shuffling) return;

    provider.setIsPlayer1Shuffling(true);
    provider.setPlayer2("?");

    checkResultWhenReady(provider, context);

    const choices = [
      CustomTextIcons.rock,
      CustomTextIcons.paper,
      CustomTextIcons.scissor,
    ];
    final random = Random();

    String finalValue = '?';

    for (int i = 0; provider.isPlayer1Shuffling; i++) {
      finalValue = choices[random.nextInt(3)];

      provider.setPlayer1(finalValue);

      await Future.delayed(const Duration(milliseconds: 80));
    }

    provider.setPlayer1(finalValue);
  }

  Future<void> shufflePlayer2Choice(BuildContext context) async {
    RPSProvider provider = Provider.of<RPSProvider>(context, listen: false);
    if (provider.isPlayer2Shuffling) return;

    provider.setIsPlayer2Shuffling(true);

    checkResultWhenReady(provider, context);

    const choices = [
      CustomTextIcons.rock,
      CustomTextIcons.paper,
      CustomTextIcons.scissor,
    ];
    final random = Random();

    String finalValue = '?';

    while (provider.isPlayer2Shuffling) {
      finalValue = choices[random.nextInt(3)];

      provider.setPlayer2(finalValue);

      await Future.delayed(const Duration(milliseconds: 80));

      provider.setPlayer2(finalValue);
    }
    provider.setPlayer2(finalValue);
  }

  Future<void> checkResultWhenReady(
    RPSProvider provider,
    BuildContext context,
  ) async {
    if (provider.isPlayer1Shuffling && provider.isPlayer2Shuffling) {
      provider.setTimer(
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
          if (provider.remainingSeconds > 0) {
            provider.setRemainingSeconds(provider.remainingSeconds - 1);
          } else {
            timer.cancel();
            provider.setIsPlayer1Shuffling(false);
            provider.setIsPlayer2Shuffling(false);
            provider.setRemainingSeconds(3);
            provider.setResult(
              getResult(provider.player1, provider.player2, context),
            );
          }
        }),
      );
      AppUtils.playSound(CustomAudios.countdownTick, context);
    }
  }

  String getResult(String p1, String p2, BuildContext context) {
    GameProvider provider = Provider.of<GameProvider>(context, listen: false);

    if (p1 == p2) {
      AppUtils.playSound(CustomAudios.drawChime, context);
      if (provider.isVsCpu) {
        AppUtils.playSound(CustomAudios.lockinChime, context);
        Future.delayed(Duration(milliseconds: 2000), () {
          shufflePlayer2Choice(context);
        });
      }
      return "Draw";
    }

    if ((p1 == CustomTextIcons.rock && p2 == CustomTextIcons.scissor) ||
        (p1 == CustomTextIcons.paper && p2 == CustomTextIcons.rock) ||
        (p1 == CustomTextIcons.scissor && p2 == CustomTextIcons.paper)) {
      provider.setPlayer1Score(provider.player1Score + 1);
      AppUtils.playSound(CustomAudios.victoryFanfare, context);
      return "Player1";
    } else if ((p2 == CustomTextIcons.rock && p1 == CustomTextIcons.scissor) ||
        (p2 == CustomTextIcons.paper && p1 == CustomTextIcons.rock) ||
        (p2 == CustomTextIcons.scissor && p1 == CustomTextIcons.paper)) {
      provider.setPlayer2Score(provider.player2Score + 1);
      AppUtils.playSound(CustomAudios.victoryFanfare, context);
      return "Player2";
    } else {
      AppUtils.playSound(CustomAudios.drawChime, context);
      return "";
    }
  }

  String getFinalResult(String player1, String player2) {
    Map<String, String> winningMessages = {
      '${CustomTextIcons.rock}_${CustomTextIcons.scissor}':
          '${CustomTextIcons.rock} crushes ${CustomTextIcons.scissor}',
      '${CustomTextIcons.scissor}_${CustomTextIcons.paper}':
          '${CustomTextIcons.scissor} cuts ${CustomTextIcons.paper}',
      '${CustomTextIcons.paper}_${CustomTextIcons.rock}':
          '${CustomTextIcons.paper} covers ${CustomTextIcons.rock}',
    };

    String key = '${player1.toLowerCase()}_${player2.toLowerCase()}';

    if (winningMessages.containsKey(key)) {
      return winningMessages[key]!;
    }

    // Check reverse combination (Player 2 wins)
    String reverseKey = '${player2.toLowerCase()}_${player1.toLowerCase()}';

    if (winningMessages.containsKey(reverseKey)) {
      return winningMessages[reverseKey]!;
    }

    return '';
  }

  void resetRPS(BuildContext context) {
    RPSProvider provider = Provider.of<RPSProvider>(context, listen: false);
    provider.setRemainingSeconds(3);
    provider.setIsPlayer1Shuffling(false);
    provider.setIsPlayer2Shuffling(false);
    provider.setPlayer1("?");
    provider.setPlayer2("?");
    provider.setResult("");
    provider.setTimer(null);
  }
}
