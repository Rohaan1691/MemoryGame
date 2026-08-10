import 'package:flutter/material.dart';
import 'package:memorygame/models/game_card_model/game_card_model.dart';
import 'package:memorygame/utils/constants.dart';

class GameProvider extends ChangeNotifier {
  int _remainingSeconds = 10;

  int get remainingSeconds => _remainingSeconds;

  void setRemainingSeconds(int value) {
    _remainingSeconds = value;
    notifyListeners();
  }

  List<GameCardModel> _cards = [];

  List<GameCardModel> get cards => _cards;

  void setCards(List<GameCardModel> value) {
    _cards = value;
    notifyListeners();
  }

  GameCardModel? _firstCard;

  GameCardModel? get firstCard => _firstCard;

  void setFirstCard(GameCardModel? value) {
    _firstCard = value;
    notifyListeners();
  }

  void setFirstCardFlip(bool value) {
    if (_firstCard != null) {
      _firstCard!.isFlipped = value;
    }
    notifyListeners();
  }

  void setFirstCardIsMatched(bool value) {
    if (_firstCard != null) {
      _firstCard!.isMatched = value;
    }
    notifyListeners();
  }

  void setFirstCardMatchedColor(Color value) {
    if (_firstCard != null) {
      _firstCard!.matchedByColor = value;
    }
    notifyListeners();
  }

  GameCardModel? _secondCard;

  GameCardModel? get secondCard => _secondCard;

  void setSecondCard(GameCardModel? value) {
    _secondCard = value;
    notifyListeners();
  }

  void setSecondCardFlip(bool value) {
    if (_secondCard != null) {
      _secondCard!.isFlipped = value;
    }
    notifyListeners();
  }

  void setSecondCardIsMatched(bool value) {
    if (_secondCard != null) {
      _secondCard!.isMatched = value;
    }
    notifyListeners();
  }

  void setSecondCardMatchedColor(Color value) {
    if (_secondCard != null) {
      _secondCard!.matchedByColor = value;
    }
    notifyListeners();
  }

  bool _isChecking = false;

  bool get isChecking => _isChecking;

  void setIsChecking(bool value) {
    _isChecking = value;
    notifyListeners();
  }

  bool _isDialogOpen = false;

  bool get isDialogOpen => _isDialogOpen;

  void setIsDialogOpen(bool value) {
    _isDialogOpen = value;
    notifyListeners();
  }

  int _player1Score = 0;

  int get player1Score => _player1Score;

  void setPlayer1Score(int value) {
    _player1Score = value;
    notifyListeners();
  }

  int _player2Score = 0;

  int get player2Score => _player2Score;

  void setPlayer2Score(int value) {
    _player2Score = value;
    notifyListeners();
  }

  bool _isPlayerOneTurn = true;

  bool get isPlayerOneTurn => _isPlayerOneTurn;

  void setIsPlayerOneTurn(bool value) {
    _isPlayerOneTurn = value;
    notifyListeners();
  }

  int _streakPlayer = Constants.invalid;

  int get streakPlayer => _streakPlayer;

  void setStreakPlayer(int value) {
    _streakPlayer = value;
    notifyListeners();
  }

  int _player1WinStreak = 0;

  int get player1WinStreak => _player1WinStreak;

  void setPlayer1WinStreak(int value) {
    _player1WinStreak = value;
    notifyListeners();
  }

  int _player2WinStreak = 0;

  int get player2WinStreak => _player2WinStreak;

  void setPlayer2WinStreak(int value) {
    _player2WinStreak = value;
    notifyListeners();
  }

  int _difficultyMode = 1;

  int get difficultyMode => _difficultyMode;

  void setDifficultyMode(int value) {
    _difficultyMode = value;
    notifyListeners();
  }

  bool _isSoundOn = true;

  bool get isSoundOn => _isSoundOn;

  void setIsSoundOn(bool value) {
    _isSoundOn = value;
    notifyListeners();
  }

  bool _isVsCpu = true;

  bool get isVsCpu => _isVsCpu;

  void setIsVsCpu(bool value) {
    _isVsCpu = value;
    notifyListeners();
  }

  bool _isShowRPS = false;

  bool get isShowRPS => _isShowRPS;

  void setIsShowRPS(bool value) {
    _isShowRPS = value;
    notifyListeners();
  }

  void resetCardModel() {
    _cards.clear();
    notifyListeners();
  }
}
