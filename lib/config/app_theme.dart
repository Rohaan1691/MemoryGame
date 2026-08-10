import 'package:flutter/material.dart';
import 'package:memorygame/utils/custom_colors.dart';
import 'package:memorygame/utils/custom_images.dart';

/// Shared visual patterns extracted from the existing screens.
///
/// Colour VALUES are not redefined here — they are imported from
/// `utils/custom_colors.dart`, which the shipped screens already use. This file
/// only captures the composed treatments (background, buttons, panels, dialog
/// shell) that are currently written inline and duplicated across
/// Main / Difficulty / Game / RPS, so the new screens can reuse them verbatim.
///
/// Nothing here is applied to existing screens; they are left untouched.
class AppTheme {
  const AppTheme._();

  // ---------------------------------------------------------------- spacing
  /// Corner radius used by every panel, button and dialog in the app.
  static const double radius = 20;

  /// Tighter radius used by in-dialog action buttons.
  static const double dialogButtonRadius = 10;

  /// Border width on the white panels of the game HUD and difficulty buttons.
  static const double panelBorderWidth = 4;

  /// Border width on the Main screen's solid mode buttons.
  static const double solidButtonBorderWidth = 2;

  // ------------------------------------------------------------ typography
  // The app declares no custom font, so everything inherits Roboto. Sizes and
  // weights below mirror the values already used on the existing screens.

  static const TextStyle heading = TextStyle(
    color: lightRed,
    fontSize: 25,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle solidButtonLabel = TextStyle(
    color: white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle panelLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle body = TextStyle(
    color: black,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle muted = TextStyle(
    color: textColor,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// Oversized emoji used as the icon at the top of every dialog.
  static const TextStyle dialogEmoji = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 50,
  );

  // ------------------------------------------------------------ background
  /// The full-bleed `game_bg.jpg` backdrop used by Splash, Main, Difficulty
  /// and Game, with content stacked on top.
  static Widget background(BuildContext context, {required Widget child}) {
    final size = MediaQuery.of(context).size;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          Center(
            child: Image.asset(
              CustomImages.gameBG,
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
            ),
          ),
          child,
        ],
      ),
    );
  }

  /// The 200x200 rounded logo shown on Splash / Main / Difficulty.
  static Widget logo({double size = 200}) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(radius)),
      child: Image.asset(
        CustomImages.flagLogo,
        width: size,
        height: size,
        fit: BoxFit.fill,
      ),
    );
  }

  // --------------------------------------------------------------- buttons
  /// Solid button matching the Main screen's TWO PLAYERS / VS COMPUTER pattern:
  /// filled colour, 2px yellow border, 20 radius, white bold 20pt label.
  static Widget solidButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
    double height = 60,
    Color borderColor = yellow,
    double fontSize = 20,
    Widget? leading,
  }) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(radius)),
          border: Border.all(color: borderColor, width: solidButtonBorderWidth),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(radius)),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 10)],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: solidButtonLabel.copyWith(fontSize: fontSize),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Outlined button matching the Difficulty screen: white fill, 4px coloured
  /// border, label tinted with the same colour.
  static Widget outlineButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
    double height = 60,
    double fontSize = 15,
  }) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(radius)),
        child: Container(
          height: height,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: white,
            borderRadius: const BorderRadius.all(Radius.circular(radius)),
            border: Border.all(color: color, width: panelBorderWidth),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compact action button used inside dialogs (10 radius), mirroring the
  /// `actionButton` helper on the Game screen.
  static Widget dialogButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
    Color labelColor = white,
  }) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(
          Radius.circular(dialogButtonRadius),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(
              Radius.circular(dialogButtonRadius),
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: labelColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- panels
  /// White rounded panel with a coloured border, as used by the Game HUD
  /// player cards.
  static BoxDecoration panel({Color borderColor = lightGrey}) {
    return BoxDecoration(
      color: white,
      borderRadius: const BorderRadius.all(Radius.circular(radius)),
      border: Border.all(color: borderColor, width: panelBorderWidth),
    );
  }

  // --------------------------------------------------------------- dialogs
  /// Dialog shell matching the Game screen's restart / exit / win dialogs:
  /// 20 radius, oversized emoji, lightRed title, body constrained to
  /// screenWidth / 2.5 so it reads well in landscape.
  static AlertDialog dialog({
    required BuildContext context,
    required String emoji,
    required String title,
    required List<Widget> children,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      title: Column(
        children: [
          Text(emoji, textAlign: TextAlign.center, style: dialogEmoji),
          Text(title, textAlign: TextAlign.center, style: heading),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width / 2.5,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
