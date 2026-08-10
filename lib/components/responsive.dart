import 'package:flutter/material.dart';

enum ScreenSize {
  small,
  medium,
  large,
}

class ScreenSizeHelper {
  static ScreenSize get(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Since your app is landscape, use the shorter side
    final shortestSide = size.shortestSide;

    if (shortestSide < 400) {
      return ScreenSize.small;
    } else if (shortestSide < 600) {
      return ScreenSize.medium;
    } else {
      return ScreenSize.large;
    }
  }

  static bool isSmall(BuildContext context) =>
      get(context) == ScreenSize.small;

  static bool isMedium(BuildContext context) =>
      get(context) == ScreenSize.medium;

  static bool isLarge(BuildContext context) =>
      get(context) == ScreenSize.large;
}