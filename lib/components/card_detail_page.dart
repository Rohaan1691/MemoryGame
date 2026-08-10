import 'package:flutter/material.dart';
import 'package:memorygame/models/game_card_model/game_card_model.dart';
import 'package:memorygame/utils/custom_colors.dart';

class DetailPage extends StatelessWidget {
  final GameCardModel cardData;
  final int difficultyMode;

  const DetailPage({
    super.key,
    required this.cardData,
    required this.difficultyMode,
  });

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context);
    });
    return Scaffold(
      backgroundColor: Colors.black54,

      body: Center(
        child: Hero(
          tag: cardData,

          flightShuttleBuilder:
              (flightContext, animation, direction, fromContext, toContext) {
                return ScaleTransition(
                  scale: animation.drive(Tween(begin: 1, end: 1.15)),
                  child: toContext.widget,
                );
              },

          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * .8,
              height: MediaQuery.of(context).size.width * .4,
              // decoration: BoxDecoration(
              //   borderRadius: BorderRadius.circular(20),
              //   color: Colors.white,
              // ),
              child: gameCard(MediaQuery.of(context).size),
            ),
          ),
        ),
      ),
    );
  }

  Widget gameCard(Size screenSize) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            cardData.country.emoji,
            style: TextStyle(
              fontSize: screenSize.width / 4,
              color: black,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Transform.translate(
          //   offset: Offset(0, -30),
          //   child: Text(
          //     cardData.country.name,
          //     textAlign: TextAlign.start,
          //     style: TextStyle(
          //       fontSize: 25,
          //       color: black,
          //       fontWeight: FontWeight.bold,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
