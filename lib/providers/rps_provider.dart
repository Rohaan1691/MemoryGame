import 'dart:async';

import 'package:flutter/cupertino.dart';

class RPSProvider extends ChangeNotifier {

  Timer? _timer;
  Timer? get timer => _timer;
  void setTimer(Timer? value){
    _timer = value;
    notifyListeners();
  }
  void cancelTimer(){
    if(_timer!=null){
      _timer!.cancel();
      notifyListeners();
    }
  }


  String _player1 = '?';

  String get player1 => _player1;

  void setPlayer1(String value) {
    _player1 = value;
    notifyListeners();
  }

  String _player2 = '?';

  String get player2 => _player2;

  void setPlayer2(String value) {
    _player2 = value;
    notifyListeners();
  }

  bool _isPlayer1Shuffling = false;

  bool get isPlayer1Shuffling => _isPlayer1Shuffling;

  void setIsPlayer1Shuffling(bool value) {
    _isPlayer1Shuffling = value;
    notifyListeners();
  }

  bool _isPlayer2Shuffling = false;

  bool get isPlayer2Shuffling => _isPlayer2Shuffling;

  void setIsPlayer2Shuffling(bool value) {
    _isPlayer2Shuffling = value;
    notifyListeners();
  }

  int _remainingSeconds = 3;

  int get remainingSeconds => _remainingSeconds;

  void setRemainingSeconds(int value) {
    _remainingSeconds = value;
    notifyListeners();
  }

  String _result = '';

  String get result => _result;

  void setResult(String value) {
    _result = value;
    notifyListeners();
  }
}
