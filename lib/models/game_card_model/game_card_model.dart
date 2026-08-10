import 'package:flutter/cupertino.dart';
import 'package:memorygame/models/countries_model/countries_model.dart';

class GameCardModel {
  final String id;
  final CountryModel country;
  bool isFlipped;
  bool isMatched;
  bool noMatch;
  Color? matchedByColor;


  GameCardModel({
    required this.id,
    required this.country,
    this.isFlipped = false,
    this.isMatched = false,
    this.noMatch = false,
    this.matchedByColor,
  });
}