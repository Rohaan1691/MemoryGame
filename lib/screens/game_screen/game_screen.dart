import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:memorygame/components/responsive.dart';
import 'package:memorygame/models/countries_model/countries_model.dart';
import 'package:memorygame/models/game_card_model/game_card_model.dart';
import 'package:memorygame/network/routes.dart';
import 'package:memorygame/providers/game_provider.dart';
import 'package:memorygame/screens/rps/rps.dart';
import 'package:memorygame/utils/app_utils.dart';
import 'package:memorygame/utils/constants.dart';
import 'package:memorygame/utils/custom_audios.dart';
import 'package:memorygame/utils/custom_colors.dart';
import 'package:memorygame/utils/custom_images.dart';
import 'package:memorygame/utils/custom_text_icons.dart';
import 'package:provider/provider.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';
import 'package:vibration/vibration.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _rotationController;

  Timer? turnTimer;

  static final Random _random = Random();

  final AudioPlayer _audioPlayer = AudioPlayer();

  /// CPU MEMORY
  final List<GameCardModel> _cpuMemory = [];
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    Future.delayed(Duration.zero, () {
      GameProvider provider = Provider.of<GameProvider>(context, listen: false);
      if (provider.difficultyMode == 1) {
        provider.setCards(generateEasyMode(Constants.countries));
      } else if (provider.difficultyMode == 2) {
        provider.setCards(generateMediumMode(Constants.countries));
      } else if (provider.difficultyMode == 3) {
        provider.setCards(generateHardMode(Constants.countries));
        Future.microtask(() {
          if (mounted) startTurnTimer();
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      turnTimer?.cancel();
      turnTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposed = true;
    turnTimer?.cancel();
    turnTimer = null;
    _rotationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

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
            padding: const EdgeInsets.fromLTRB(70, 20, 70, 20),
            child: Selector<GameProvider, Map<String, dynamic>>(
              selector: (context, provider) => {
                'isPlayerOneTurn': provider.isPlayerOneTurn,
                'player1Score': provider.player1Score,
                'player1WinStreak': provider.player1WinStreak,
                'isVsCpu': provider.isVsCpu,
                'player2Score': provider.player2Score,
                'player2WinStreak': provider.player2WinStreak,
                'difficultyMode': provider.difficultyMode,
                'remainingSeconds': provider.remainingSeconds,
                'isSoundOn': provider.isSoundOn,
                'cards': provider.cards,
              },
              builder: (context, data, _) {
                final bool isPlayerOneTurn = data['isPlayerOneTurn'];
                final int player1Score = data['player1Score'];
                final int player1WinStreak = data['player1WinStreak'];
                final bool isVsCpu = data['isVsCpu'];
                final int player2Score = data['player2Score'];
                final int player2WinStreak = data['player2WinStreak'];
                final int difficultyMode = data['difficultyMode'];
                final int remainingSeconds = data['remainingSeconds'];
                final bool isSoundOn = data['isSoundOn'];
                final List<GameCardModel> cards = data['cards'];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 60,
                            padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
                            decoration: BoxDecoration(
                              color: white,
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                              border: Border.all(
                                color: isPlayerOneTurn ? cyan : lightGrey,
                                width: 4,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ScreenSizeHelper.isSmall(context) ? 'P 1' : 'PLAYER 1',
                                        style: TextStyle(
                                          color: cyan,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Text(
                                      '$player1Score',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: black,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          ...List.generate(
                                            3,
                                            (index) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              child: Icon(
                                                Icons.circle,
                                                size: 15,
                                                color: index < player1WinStreak
                                                    ? cyan
                                                    : lightGrey,
                                              ),
                                            ),
                                          ),
                                          if (player1WinStreak > 3)
                                            Text(
                                              " +${player1WinStreak - 3}",
                                              style: TextStyle(
                                                color: cyan,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      player1WinStreak >= 3 &&
                                              player1WinStreak < 5
                                          ? "🔥"
                                          : player1WinStreak >= 5 &&
                                                player1WinStreak < 7
                                          ? "⚡"
                                          : player1WinStreak >= 7 &&
                                                player1WinStreak < 10
                                          ? "🧠"
                                          : player1WinStreak >= 10 &&
                                                player1WinStreak < 15
                                          ? "👑"
                                          : player1WinStreak >= 15 &&
                                                player1WinStreak < 20
                                          ? "🚀"
                                          : player1WinStreak >= 20
                                          ? "🌍"
                                          : "",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 60,
                            padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
                            decoration: BoxDecoration(
                              color: white,
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                              border: Border.all(
                                color: !isPlayerOneTurn ? pink : lightGrey,
                                width: 4,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isVsCpu ? 'CPU' : ScreenSizeHelper.isSmall(context) ? 'P 2' : 'PLAYER 2',
                                        style: TextStyle(
                                          color: pink,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Text(
                                      '$player2Score',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: black,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          ...List.generate(
                                            3,
                                            (index) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              child: Icon(
                                                Icons.circle,
                                                size: 15,
                                                color: index < player2WinStreak
                                                    ? pink
                                                    : lightGrey,
                                              ),
                                            ),
                                          ),
                                          if (player2WinStreak > 3)
                                            Text(
                                              " +${player2WinStreak - 3}",
                                              style: TextStyle(
                                                color: pink,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      player2WinStreak >= 3 &&
                                              player2WinStreak < 5
                                          ? "🔥"
                                          : player2WinStreak >= 5 &&
                                                player2WinStreak < 7
                                          ? "⚡"
                                          : player2WinStreak >= 7 &&
                                                player2WinStreak < 10
                                          ? "🧠"
                                          : player2WinStreak >= 10 &&
                                                player2WinStreak < 15
                                          ? "👑"
                                          : player2WinStreak >= 15 &&
                                                player2WinStreak < 20
                                          ? "🚀"
                                          : player2WinStreak >= 20
                                          ? "🌍"
                                          : "",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (difficultyMode == 3) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 110,
                            height: 60,
                            padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                            decoration: BoxDecoration(
                              color: white,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RotationTransition(
                                  turns: _rotationController,
                                  child: const Text(
                                    '⏳',
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Text(
                                  '${remainingSeconds < 10 ? "0" : ""}$remainingSeconds',
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: actionButton(
                            lightRed,
                            white,
                            CustomTextIcons.restart,
                            ScreenSizeHelper.isSmall(context) ? '' : 'RESTART',
                            20,
                            () {
                              GameProvider provider = Provider.of<GameProvider>(context, listen: false);
                              provider.setIsDialogOpen(true);
                              showRestartDialog(provider);
                            },
                            true,
                            difficultyMode == 3 ? 11 : 15,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: actionButton(
                            lightGrey,
                            black,
                            CustomTextIcons.home,
                            ScreenSizeHelper.isSmall(context) ? '' : 'MENU',
                            20,
                            () {
                              showExitDialog();
                            },
                            true,
                            difficultyMode == 3 ? 13 : 15,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: actionButton(
                            green,
                            white,
                            isSoundOn
                                ? CustomTextIcons.speakerOn
                                : CustomTextIcons.speakerOff,
                            ScreenSizeHelper.isSmall(context) ? '' : 'SOUND',
                            20,
                            () {
                              GameProvider provider = Provider.of<GameProvider>(
                                context,
                                listen: false,
                              );
                              provider.setIsSoundOn(!isSoundOn);
                            },
                            true,
                            difficultyMode == 3 ? 11 : 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ResponsiveGridList(
                        horizontalGridSpacing: 16,
                        verticalGridSpacing: 16,
                        horizontalGridMargin: 0,
                        verticalGridMargin: 0,
                        minItemWidth: screenSize.width / 7,
                        minItemsPerRow: difficultyMode == 1
                            ? 4
                            : difficultyMode == 2
                            ? 6
                            : difficultyMode == 3
                            ? 8
                            : 3,
                        maxItemsPerRow: difficultyMode == 1
                            ? 4
                            : difficultyMode == 2
                            ? 6
                            : difficultyMode == 3
                            ? 8
                            : 3,
                        children: List.generate(
                          cards.length,
                          (index) => gameCard(
                            screenSize,
                            cards[index],
                            difficultyMode,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
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
    double radius,
    Function onTap,
    isShowIcon,
    double fontSize,
  ) {
    Size screenSize = MediaQuery.of(context).size;
    return InkWell(
      onTap: () {
        onTap();
      },
      child: Container(
        height: screenSize.width / 17,
        padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isShowIcon)
              Text(
                icon,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (title.isNotEmpty)
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget gameCard(Size screenSize, GameCardModel cardData, int difficultyMode) {
    final bool shouldFlip = cardData.isFlipped || cardData.isMatched;

    return TweenAnimationBuilder<double>(
      key: ValueKey(cardData.id),

      tween: Tween<double>(begin: 0, end: cardData.noMatch ? 1 : 0),

      duration: const Duration(milliseconds: 380),

      builder: (context, shakeValue, child) {
        final double shakeOffset = cardData.noMatch
            ? sin(shakeValue * pi * 4) * 5
            : 0;

        return Transform.translate(
          offset: Offset(shakeOffset, 0),

          child: GestureDetector(
            onTap: () {
              onCardTap(cardData);
            },

            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: shouldFlip ? pi : 0),

              curve: Curves.easeInOut,

              duration: const Duration(milliseconds: 420),

              builder: (context, angle, child) {
                final isFront = angle >= pi / 2;

                double scale = 1.0;

                if (shouldFlip) {
                  if (angle <= pi / 2) {
                    scale = 1.2 + (angle / (pi / 2)) * 0.12;
                  } else {
                    scale = 1.12 - ((angle - pi / 2) / (pi / 2)) * 0.12;
                  }
                }

                return Transform.scale(
                  scale: scale,

                  child: Transform(
                    alignment: Alignment.center,

                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),

                    child: Container(
                      height: screenSize.width / 11,

                      decoration: BoxDecoration(
                        color: cardData.isMatched
                            ? Colors.green.shade100
                            : isFront
                            ? white
                            : purple,

                        borderRadius: BorderRadius.circular(15),

                        border: Border.all(
                          color: cardData.isMatched
                              ? cardData.matchedByColor ?? green
                              : purple,

                          width: 3,
                        ),
                      ),

                      child: Transform(
                        alignment: Alignment.center,

                        transform: Matrix4.identity()
                          ..rotateY(isFront ? pi : 0),

                        child: Stack(
                          alignment: Alignment.center,

                          children: [
                            Align(
                              alignment: Alignment.topCenter,

                              child: Transform.translate(
                                offset: Offset(0, isFront ? -10 : 0),

                                child: Text(
                                  isFront
                                      ? cardData.country.emoji
                                      : CustomTextIcons.globe,

                                  style: TextStyle(
                                    fontSize: screenSize.width / 17,

                                    color: isFront ? black : white,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            if (isFront)
                              Align(
                                alignment: Alignment.bottomCenter,

                                child: Transform.translate(
                                  offset: const Offset(0, -5),

                                  child: Text(
                                    cardData.country.name,

                                    textAlign: TextAlign.center,

                                    style: TextStyle(
                                      fontSize: difficultyMode == 2
                                          ? 13
                                          : difficultyMode == 3
                                          ? 10
                                          : 15,

                                      color: black,

                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void changeTurnByTimeout() {
    GameProvider provider = Provider.of<GameProvider>(context, listen: false);
    if (provider.isChecking) return;

    if (provider.firstCard != null && !provider.firstCard!.isMatched) {
      provider.setFirstCardFlip(false);
    }

    provider.setFirstCard(null);
    provider.setSecondCard(null);

    provider.setIsPlayerOneTurn(!provider.isPlayerOneTurn);

    if (provider.difficultyMode == 3 && mounted && !_isDisposed) {
      startTurnTimer();
    }
  }

  double _cpuMemoryChance(int difficultyMode) {
    switch (difficultyMode) {
      case 1:
        return 0.30; // Easy
      case 2:
        return 0.80; // Medium
      case 3:
        return 1.00; // Hard
      default:
        return 0.50;
    }
  }

  int _cpuMemoryLimit(int difficultyMode) {
    switch (difficultyMode) {
      case 1:
        return 4;
      case 2:
        return 8;
      case 3:
        return 999;
      default:
        return 4;
    }
  }

  void _cpuRemember(GameCardModel card, int difficultyMode) {
    if (_cpuMemory.any((e) => e == card)) return;

    _cpuMemory.add(card);

    final limit = _cpuMemoryLimit(difficultyMode);

    while (_cpuMemory.length > limit) {
      _cpuMemory.removeAt(0);
    }
  }

  void _cpuForgetMatchedCards() {
    _cpuMemory.removeWhere((card) => card.isMatched);
  }

  List<GameCardModel>? _findKnownPair() {
    for (int i = 0; i < _cpuMemory.length; i++) {
      for (int j = i + 1; j < _cpuMemory.length; j++) {
        if (_cpuMemory[i].country.code == _cpuMemory[j].country.code &&
            !_cpuMemory[i].isMatched &&
            !_cpuMemory[j].isMatched &&
            !_cpuMemory[i].isFlipped &&
            !_cpuMemory[j].isFlipped) {
          return [_cpuMemory[i], _cpuMemory[j]];
        }
      }
    }

    return null;
  }

  Future<void> onCardTap(
    GameCardModel tappedCard, {
    bool isCpuMove = false,
  }) async {
    GameProvider provider = Provider.of<GameProvider>(context, listen: false);

    if (provider.isVsCpu && !isCpuMove && !provider.isPlayerOneTurn) {
      return;
    }

    if (provider.isChecking) return;

    if (tappedCard.isFlipped || tappedCard.isMatched) {
      return;
    }

    setState(() {
      tappedCard.isFlipped = true;
      if (provider.isVsCpu) {
        _cpuRemember(tappedCard, provider.difficultyMode);
      }
    });

    if (provider.firstCard == null) {
      provider.setFirstCard(tappedCard);
      if (provider.difficultyMode == 3 && mounted && !_isDisposed) {
        startTurnTimer();
      }
      return;
    }

    provider.setSecondCard(tappedCard);

    provider.setIsChecking(true);

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _isDisposed) return;

    final audioPath = AppUtils.getAudioPath(provider.firstCard!.country.code);

    if (provider.firstCard!.country.code == provider.secondCard!.country.code) {
      if (provider.isSoundOn) {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource(CustomAudios.matchChime));
        await Future.delayed(const Duration(milliseconds: 500));
      }
      provider.setFirstCardIsMatched(true);
      provider.setSecondCardIsMatched(true);

      _cpuForgetMatchedCards();

      Color matchedColor = provider.isPlayerOneTurn ? cyan : pink;

      provider.setFirstCardMatchedColor(matchedColor);
      provider.setSecondCardMatchedColor(matchedColor);

      if (provider.isPlayerOneTurn) {
        provider.setPlayer1Score(provider.player1Score + 1);
      } else {
        provider.setPlayer2Score(provider.player2Score + 1);
      }
      if (provider.difficultyMode == 3 && mounted && !_isDisposed) {
        startTurnTimer();
      }

      if (audioPath != null && provider.isSoundOn) {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource(audioPath));
      }

      if (audioPath != null && provider.isSoundOn) {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource(audioPath));
      }
    } else {
      if (provider.isSoundOn) {
        await _audioPlayer.stop();

        await _audioPlayer.play(AssetSource(CustomAudios.wrong));
      }

      if (provider.isSoundOn && await Vibration.hasVibrator()) {
        Vibration.vibrate();
      }

      final firstCard = provider.firstCard!;
      final secondCard = provider.secondCard!;

      firstCard.noMatch = true;
      secondCard.noMatch = true;

      setState(() {});

      await Future.delayed(const Duration(milliseconds: 880));

      // remove shake + flip back together
      firstCard.noMatch = false;
      secondCard.noMatch = false;

      firstCard.isFlipped = false;
      secondCard.isFlipped = false;

      setState(() {});

      provider.setIsPlayerOneTurn(!provider.isPlayerOneTurn);

      if (provider.difficultyMode == 3 && mounted && !_isDisposed) {
        startTurnTimer();
      }
    }

    provider.setFirstCard(null);
    provider.setSecondCard(null);

    provider.setIsChecking(false);

    if (!provider.isPlayerOneTurn && provider.isVsCpu && !provider.isDialogOpen) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted || _isDisposed) return;
        cpuTurn(provider);
      });
    }

    checkGameCompleted(provider, false);
  }

  Future<void> checkGameCompleted(
    GameProvider provider,
    bool fromTieBreaker,
  ) async {
    bool allMatched = provider.cards.every((card) => card.isMatched);

    if (allMatched) {
      String winnerText = '';

      if (provider.player1Score > provider.player2Score) {
        provider.setPlayer1WinStreak(provider.player1WinStreak + 1);
        provider.setPlayer2WinStreak(0);
        provider.setStreakPlayer(Constants.player1);
        winnerText = provider.isVsCpu ? "YOU WIN!" : "PLAYER 1 WINS!";
      } else if (provider.player2Score > provider.player1Score) {
        provider.setPlayer2WinStreak(provider.player2WinStreak + 1);
        provider.setPlayer1WinStreak(0);
        provider.setStreakPlayer(Constants.player2);
        winnerText = provider.isVsCpu ? 'CPU WINS!' : 'PLAYER 2 WINS!';
      } else {
        await Future.delayed(Duration(milliseconds: 800));
        AppUtils.playSound(CustomAudios.tiebreakerChime, context);
        winnerText = 'MATCH DRAW';
      }

      if (winnerText.contains("MATCH DRAW")) {
        showGeneralDialog(
          context: context,
          barrierDismissible: false,
          fullscreenDialog: true,
          pageBuilder: (context, animation, secondaryAnimation) {
            return StatefulBuilder(
              builder: (context, st) {
                return Scaffold(body: Rps());
              },
            );
          },
        ).whenComplete(() {
          checkGameCompleted(provider, true);
        });
      } else {
        if (!fromTieBreaker) {
          await Future.delayed(Duration(milliseconds: 1000));
        }
        checkWinStreaks(winnerText, provider, fromTieBreaker);
      }
    }
  }

  void showWinDialog(
    String winnerText,
    GameProvider provider,
    bool fromTieBreaker,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, st) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Column(
                children: [
                  Text(
                    "🏆",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 50,
                    ),
                  ),
                  Text(
                    winnerText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 25,
                      color: lightRed,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width / 2.5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fromTieBreaker
                          ? provider.player2Score > provider.player1Score
                                ? "Player 2 took the tiebreaker!"
                                : 'Player 1 took the tiebreaker!'
                          : (provider.player1WinStreak == 3 ||
                                provider.player2WinStreak == 3)
                          ? '🔥 Fire - 3 wins in a row'
                          : (provider.player1WinStreak == 5 ||
                                provider.player2WinStreak == 5)
                          ? "⚡ Lightning - 5 wins in a row"
                          : (provider.player1WinStreak == 7 ||
                                provider.player2WinStreak == 7)
                          ? "🧠 Memory Master - 7 wins in a row"
                          : (provider.player1WinStreak == 10 ||
                                provider.player2WinStreak == 10)
                          ? "👑 Flag Legend - 10 wins in a row"
                          : (provider.player1WinStreak == 15 ||
                                provider.player2WinStreak == 15)
                          ? "🚀 Unstoppable - 15 wins in a row"
                          : (provider.player1WinStreak == 20 ||
                                provider.player2WinStreak == 20)
                          ? "🌍 World Champion - 20 wins in a row"
                          : provider.player1Score == provider.player2Score
                          ? "It's a Tie!"
                          : provider.isVsCpu
                          ? provider.player2Score > provider.player1Score
                                ? "The computer was too sharp!"
                                : "You outsmarted the computer!"
                          : 'Excellent Memory!',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                          decoration: BoxDecoration(
                            color: cyan.withOpacity(0.2),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            border: Border.all(color: cyan, width: 3),
                          ),
                          child: Text(
                            'P1: ${provider.player1Score}',
                            style: const TextStyle(
                              color: cyan,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                          decoration: BoxDecoration(
                            color: pink.withOpacity(0.2),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            border: Border.all(color: pink, width: 3),
                          ),
                          child: Text(
                            provider.isVsCpu
                                ? 'CPU: ${provider.player2Score}'
                                : 'P2: ${provider.player2Score}',
                            style: const TextStyle(
                              color: pink,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 1,
                          child: actionButton(
                            lightRed,
                            white,
                            CustomTextIcons.restart,
                            'PLAY AGAIN',
                            10,
                            () async {
                              AppUtils.pop(context);
                              showRandomCountryDialog(provider);
                            },
                            false,
                            15,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: actionButton(
                            blue,
                            white,
                            CustomTextIcons.home,
                            'MENU',
                            10,
                            () {
                              restartGame(true);
                              AppUtils.pop(context);
                              AppUtils.popAndPushNamed(context, Routes.main);
                            },
                            false,
                            15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> showRandomCountryDialog(GameProvider provider) async {
    final random = Random();
    final country =
        Constants.countries[random.nextInt(Constants.countries.length)];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width / 2.5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "🌍 ",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      " Did You Know?",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 25,
                        color: lightRed,
                      ),
                    ),
                  ],
                ),
                Text(
                  country.emoji,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 70,
                  ),
                ),
                Text(
                  country.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  country.fact,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 200,
                  child: actionButton(
                    blue,
                    white,
                    CustomTextIcons.restart,
                    'Continue Playing',
                    30,
                    () {
                      restartGame(false);
                      AppUtils.pop(context);
                    },
                    false,
                    15,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    final audioPath = AppUtils.getAudioPath(country.code);
    if (audioPath != null && provider.isSoundOn) {
      await _audioPlayer.stop();

      await _audioPlayer.play(AssetSource(audioPath));
    }
  }

  void checkWinStreaks(
    String winnerText,
    GameProvider provider,
    bool fromTieBreaker,
  ) {
    GameProvider provider = Provider.of<GameProvider>(context, listen: false);

    int streak = provider.streakPlayer == Constants.player1
        ? provider.player1WinStreak == 3 ||
                  provider.player1WinStreak == 5 ||
                  provider.player1WinStreak == 7 ||
                  provider.player1WinStreak == 10 ||
                  provider.player1WinStreak == 15 ||
                  provider.player1WinStreak == 20
              ? provider.player1WinStreak
              : 0
        : provider.streakPlayer == Constants.player2
        ? provider.player2WinStreak == 3 ||
                  provider.player2WinStreak == 5 ||
                  provider.player2WinStreak == 7 ||
                  provider.player2WinStreak == 10 ||
                  provider.player2WinStreak == 15 ||
                  provider.player2WinStreak == 20
              ? provider.player2WinStreak
              : 0
        : 0;

    String audio = "";
    if (streak == 3) {
      audio = CustomAudios.onFire;
    } else if (streak == 5) {
      audio = CustomAudios.lightningFast;
    } else if (streak == 7) {
      audio = CustomAudios.memoryMaster;
    } else if (streak == 10) {
      audio = CustomAudios.flagLegend;
    } else if (streak == 15) {
      audio = CustomAudios.unstoppable;
    } else if (streak == 20) {
      audio = CustomAudios.worldChampion;
    }

    if (audio.isNotEmpty) {
      AppUtils.playSound(audio, context);
    }
    showWinDialog(winnerText, provider, fromTieBreaker);
  }

  Future<void> cpuTurn(GameProvider provider) async {
    if (!mounted || _isDisposed) return;

    if (provider.isPlayerOneTurn) return;

    if (provider.isChecking) return;

    final difficultyMode = provider.difficultyMode;

    final delay = difficultyMode == 1
        ? 1000
        : difficultyMode == 2
        ? 750
        : 500;

    await Future.delayed(Duration(milliseconds: delay));
    if (!mounted || _isDisposed) return;

    final availableCards = provider.cards
        .where((c) => !c.isMatched && !c.isFlipped)
        .toList();

    if (availableCards.length < 2) return;

    final knownPair = _findKnownPair();

    final useMemory =
        knownPair != null &&
        _random.nextDouble() < _cpuMemoryChance(difficultyMode);

    GameCardModel firstPick;
    GameCardModel secondPick;

    if (useMemory) {
      firstPick = knownPair[0];
      secondPick = knownPair[1];
    } else {
      availableCards.shuffle();

      firstPick = availableCards[0];

      final remaining = availableCards.where((e) => e != firstPick).toList();

      remaining.shuffle();

      secondPick = remaining[0];
    }

    if (!provider.isPlayerOneTurn) {
      await onCardTap(firstPick, isCpuMove: true);
    }

    await Future.delayed(Duration(milliseconds: delay));
    if (!mounted || _isDisposed) return;
    if (!provider.isPlayerOneTurn) {
      await onCardTap(secondPick, isCpuMove: true);
    }
  }

  void startTurnTimer() {
    GameProvider provider = Provider.of<GameProvider>(context, listen: false);

    if (provider.difficultyMode != 3 || !mounted || _isDisposed) return;

    turnTimer?.cancel();
    turnTimer = null;

    provider.setRemainingSeconds(10);

    turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isDisposed) {
        turnTimer?.cancel();
        return;
      }

      if (provider.isChecking) return;

      if(!provider.isDialogOpen) {
        if (provider.remainingSeconds > 0) {
          provider.setRemainingSeconds(provider.remainingSeconds - 1);
        } else {
          turnTimer?.cancel();
          turnTimer = null;
          changeTurnByTimeout();

          if (!provider.isPlayerOneTurn && provider.isVsCpu && !provider.isDialogOpen) {
            if (mounted && !_isDisposed) {
              cpuTurn(provider);
            }
          } else {
            if (mounted && !_isDisposed) {
              startTurnTimer();
            }
          }
        }
      }
    });
  }

  Future<void> restartGame(bool isClearWinStreak) async {
    await Future.delayed(Duration(milliseconds: 200));
    GameProvider provider = Provider.of<GameProvider>(context, listen: false);

    _cpuMemory.clear();
    provider.setFirstCard(null);
    provider.setSecondCard(null);
    provider.setIsChecking(false);
    provider.setPlayer1Score(0);
    provider.setPlayer2Score(0);
    provider.setIsPlayerOneTurn(true);
    provider.setIsDialogOpen(false);
    if (isClearWinStreak) {
      provider.setPlayer1WinStreak(0);
      provider.setPlayer2WinStreak(0);
      provider.setStreakPlayer(Constants.invalid);
    }

    if (provider.difficultyMode == 1) {
      provider.setCards(generateEasyMode(Constants.countries));
    } else if (provider.difficultyMode == 2) {
      provider.setCards(generateMediumMode(Constants.countries));
    } else if (provider.difficultyMode == 3) {
      provider.setRemainingSeconds(10);
      provider.setCards(generateHardMode(Constants.countries));
    }
  }

  /// EASY MODE
  List<GameCardModel> generateEasyMode(List<CountryModel> countries) {
    return _generateCards(countries, 6);
  }

  /// MEDIUM MODE
  List<GameCardModel> generateMediumMode(List<CountryModel> countries) {
    return _generateCards(countries, 9);
  }

  /// HARD MODE
  List<GameCardModel> generateHardMode(List<CountryModel> countries) {
    return _generateCards(countries, 12);
  }

  /// COMMON
  int _cardCounter = 0;

  List<GameCardModel> _generateCards(
    List<CountryModel> countries,
    int pairCount,
  ) {
    final shuffledCountries = List<CountryModel>.from(countries);
    shuffledCountries.shuffle(_random);

    final selectedCountries = shuffledCountries.take(pairCount).toList();

    List<GameCardModel> cards = [];

    for (final country in selectedCountries) {
      cards.add(GameCardModel(id: 'card_${_cardCounter++}', country: country));

      cards.add(GameCardModel(id: 'card_${_cardCounter++}', country: country));
    }

    cards.shuffle(_random);
    return cards;
  }

  void showExitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Text(
                "🏃🚪",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 50,
                ),
              ),
              Text(
                "Exit Game",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                  color: lightRed,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width / 2.5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Text(
                  "Are you sure you want to leave this game? Your current progress will be lost.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 1,
                      child: actionButton(
                        lightRed,
                        white,
                        CustomTextIcons.restart,
                        'Cancel',
                        10,
                        () {
                          AppUtils.pop(context);
                        },
                        false,
                        15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: actionButton(
                        blue,
                        white,
                        CustomTextIcons.cross,
                        'Exit',
                        10,
                        () {
                          turnTimer?.cancel();
                          restartGame(true);
                          AppUtils.popAndPushNamed(context, Routes.main);
                        },
                        false,
                        15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showRestartDialog(GameProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Text(
                "🔄",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 50,
                ),
              ),
              Text(
                "Restart Game",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                  color: lightRed,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width / 2.5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Text(
                  "Are you sure you want to restart this game? Your current progress will be lost.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 1,
                      child: actionButton(
                        lightRed,
                        white,
                        CustomTextIcons.restart,
                        'Cancel',
                        10,
                        () {
                          provider.setIsDialogOpen(false);
                          if(provider.isVsCpu) {
                            cpuTurn(provider);
                          }
                          AppUtils.pop(context);
                        },
                        false,
                        15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: actionButton(
                        blue,
                        white,
                        CustomTextIcons.cross,
                        'Restart',
                        10,
                        () {
                          restartGame(true);
                          AppUtils.pop(context);
                        },
                        false,
                        15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget winStreak(Size screenSize, String image) {
    return Padding(
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Image.asset(image, fit: BoxFit.fill),
      ),
    );
  }
}
