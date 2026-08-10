import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:memorygame/providers/game_provider.dart';
import 'package:memorygame/utils/custom_audios.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUtils {
  static statusBarNavigationBar(int value, Brightness brightness) {
    if (value == 1) {
      return SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness,
        ),
      );
    } else if (value == 2) {
      return SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top],
      );
    } else {
      return SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [],
      );
    }
  }

  static void pop(BuildContext context) {
    Navigator.pop(context);
  }

  static void popAndPushNamed(BuildContext context, var screen) {
    Navigator.popAndPushNamed(context, screen);
  }

  static void pushNamed(BuildContext context, var screen, {Object? arguments}) {
    Navigator.pushNamed(context, screen, arguments: arguments);
  }

  static void showToast(String msg, Color backgroundColor, Color textColor) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: backgroundColor,
      webBgColor: "linear-gradient(to right, #00529E, #00529E)",
      textColor: textColor,
      fontSize: 10.0,
    );
  }

  static void showSnackBar(BuildContext context, String text) {
    final snackBar = SnackBar(
      content: Text(text),
      backgroundColor: Colors.black,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static Future<String?> readSP(var key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    if (kDebugMode) {
      print('read: $key $value');
    }
    return value;
  }

  static Future<bool> readBoolSP(var key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(key) ?? false;
    if (kDebugMode) {
      print('read: $key is $value');
    }
    return value;
  }

  static Future<void> removeAllSP() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
  }

  static Future<void> removeSP(var key) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(key)) {
      prefs.remove(key);
    }
    if (kDebugMode) {
      print('$key: removed');
    }
  }

  static Future<void> saveSP(var key, var value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      prefs.setString(key, value);
    } else if (value is int) {
      prefs.setInt(key, value);
    } else if (value is bool) {
      prefs.setBool(key, value);
    }
    if (kDebugMode) {
      print('saved: $key = $value');
    }
  }

  static String getCurrentDateYYMMDD() {
    String currentDate = "";
    DateTime date = DateTime.now();
    currentDate = "${date.year}-${date.month}-${date.day}";
    return currentDate;
  }

  static String getCurrentDateYYMMDDHHMMSS() {
    String currentDate = "";
    DateTime date = DateTime.now();
    currentDate =
        "${date.year}-${date.month}-${date.day}  ${date.hour}:${date.minute}:${date.second}";
    return currentDate;
  }

  static String parseDateYYMMDDHHMMSS(String date) {
    String result = date;
    if (date.contains("T")) {
      var parsedDate = DateTime.parse(date);
      String month = parsedDate.month < 10
          ? "0${parsedDate.month}"
          : "${parsedDate.month}";
      String day = parsedDate.day < 10
          ? "0${parsedDate.day}"
          : "${parsedDate.day}";
      String hour = parsedDate.hour < 10
          ? "0${parsedDate.hour}"
          : "${parsedDate.hour}";
      String minutes = parsedDate.minute < 10
          ? "0${parsedDate.minute}"
          : "${parsedDate.minute}";
      String seconds = parsedDate.second < 10
          ? "0${parsedDate.second}"
          : "${parsedDate.second}";
      result = "${parsedDate.year}-$month-$day $hour:$minutes:$seconds";
    }
    return result;
  }

  static String parseDateDDMMYY(String date) {
    String result = date;

    var parsedDate = DateTime.parse(date);
    String month = parsedDate.month < 10
        ? "0${parsedDate.month}"
        : "${parsedDate.month}";
    String day = parsedDate.day < 10
        ? "0${parsedDate.day}"
        : "${parsedDate.day}";
    result = "$day / $month / ${parsedDate.year}";

    return result;
  }

  static String formatDate(DateTime date, String separator) {
    String day = date.day < 10 ? '0${date.day}' : date.day.toString();
    String month = date.month < 10 ? '0${date.month}' : date.month.toString();
    String year = date.year.toString();
    debugPrint("DATE: $day$separator$month$separator$year");
    return "$day$separator$month$separator$year";
  }

  static String formatDateYYYYMMDD(DateTime date, String separator) {
    String day = date.day < 10 ? '0${date.day}' : date.day.toString();
    String month = date.month < 10 ? '0${date.month}' : date.month.toString();
    String year = date.year.toString();
    debugPrint("DATE: $day$separator$month$separator$year");
    return "$year$separator$month$separator$day";
  }

  static String getTimestamp() {
    String timestamp = "";
    timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return timestamp;
  }

  static bool isValidEmail(String email) {
    bool isValid = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+\.[a-zA-Z]+",
    ).hasMatch(email);
    return isValid;
  }

  static bool isValidPassword(String email) {
    bool isValid = RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[!@#$%^&*])[A-Za-z\d!@#$%^&*]{8,}$',
    ).hasMatch(email);
    return isValid;
  }

  static bool isValidContact(String contact) {
    bool isValid = RegExp(
      r"^03(0[0-4]|1[0-8]|2[0-9]|3[0-9]|4[0-8]|5[0-9]|6[0-6]|7[0-7]|8[0-5])\d{7}$",
    ).hasMatch(contact);
    return isValid;
  }

  static String getInitials(String text) {
    if (text.trim().isEmpty) return '';

    final words = text.trim().split(RegExp(r'\s+'));
    final initials = words.map((word) => word[0]).join();

    return initials.toUpperCase();
  }

  static String convertMapToString(Map<String, List<Object>> map) {
    StringBuffer sb = StringBuffer();

    map.forEach((key, value) {
      sb.write('$key: [');
      for (int i = 0; i < value.length; i++) {
        sb.write(value[i].toString());
        if (i < value.length - 1) {
          sb.write(', ');
        }
      }
      sb.write(']\n');
    });

    return sb.toString();
  }

  static String getUniqueId() {
    String id = UniqueKey().toString();
    if (id.length > 5) {
      id = id.substring(2, 7);
    }
    return id;
  }

  static int generateRandomNumber(int length) {
    return Random().nextInt(length);
  }

  static String formatTime(TimeOfDay time) {
    return "${time.hour}:${time.minute} ${time.period.name}";
  }

  static void playSound(String sound, BuildContext context) async {
    GameProvider provider = Provider.of<GameProvider>(context, listen: false);
    if(provider.isSoundOn) {
      final AudioPlayer audioPlayer = AudioPlayer();
      await audioPlayer.stop();
      await audioPlayer.play(AssetSource(sound));
    }
  }

  static String? getAudioPath(String countryCode) {
    switch (countryCode) {
      case 'ar':
        return CustomAudios.argentina;
      case 'au':
        return CustomAudios.australia;
      case 'at':
        return CustomAudios.austria;
      case 'be':
        return CustomAudios.belgium;
      case 'br':
        return CustomAudios.brazil;
      case 'ca':
        return CustomAudios.canada;
      case 'cl':
        return CustomAudios.chile;
      case 'cn':
        return CustomAudios.china;
      case 'cr':
        return CustomAudios.costaRica;
      case 'hr':
        return CustomAudios.croatia;
      case 'cu':
        return CustomAudios.cuba;
      case 'dk':
        return CustomAudios.denmark;
      case 'eg':
        return CustomAudios.egypt;
      case 'fi':
        return CustomAudios.finland;
      case 'fr':
        return CustomAudios.france;
      case 'de':
        return CustomAudios.germany;
      case 'gr':
        return CustomAudios.greece;
      case 'hu':
        return CustomAudios.hungary;
      case 'is':
        return CustomAudios.iceland;
      case 'in':
        return CustomAudios.india;
      case 'ie':
        return CustomAudios.ireland;
      case 'it':
        return CustomAudios.italy;
      case 'jp':
        return CustomAudios.japan;
      case 'ke':
        return CustomAudios.kenya;
      case 'mx':
        return CustomAudios.mexico;
      case 'nl':
        return CustomAudios.netherlands;
      case 'nz':
        return CustomAudios.newZealand;
      case 'ng':
        return CustomAudios.nigeria;
      case 'no':
        return CustomAudios.norway;
      case 'pk':
        return CustomAudios.pakistan;
      case 'pe':
        return CustomAudios.peru;
      case 'pl':
        return CustomAudios.poland;
      case 'pt':
        return CustomAudios.portugal;
      case 'sg':
        return CustomAudios.singapore;
      case 'za':
        return CustomAudios.southAfrica;
      case 'kr':
        return CustomAudios.southKorea;
      case 'es':
        return CustomAudios.spain;
      case 'se':
        return CustomAudios.sweden;
      case 'ch':
        return CustomAudios.switzerland;
      case 'th':
        return CustomAudios.thailand;
      case 'tr':
        return CustomAudios.turkey;
      case 'gb':
        return CustomAudios.uk;
      case 'us':
        return CustomAudios.usa;
      default:
        return null;
    }
  }
}
