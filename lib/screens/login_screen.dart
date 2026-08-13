import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:memorygame/config/app_theme.dart';
import 'package:memorygame/network/routes.dart';
import 'package:memorygame/services/auth_service.dart';
import 'package:memorygame/utils/app_utils.dart';
import 'package:memorygame/utils/custom_colors.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Optional sign-in. The game is fully playable without an account, so
/// "Play as guest" is always visible and routes straight to the Main screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Resolve Apple availability so the button can be hidden on Android.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthService>().init();
    });
  }

  Future<void> _handle(Future<AuthOutcome> Function() action) async {
    if (_busy) return; // guard against double-taps
    setState(() => _busy = true);
    try {
      final outcome = await action();
      if (!mounted) return;

      if (outcome.isSuccess) {
        AppUtils.popAndPushNamed(context, Routes.main);
        return;
      }
      if (outcome.isCancelled) {
        // User backed out of the sheet. Show nothing at all.
        return;
      }
      _showError(outcome.message ?? 'Sign-in failed, please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppTheme.dialog(
          context: dialogContext,
          emoji: '⚠️',
          title: 'Sign-in Failed',
          children: [
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: AppTheme.body),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: AppTheme.dialogButton(
                label: 'OK',
                color: blue,
                onTap: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final appleAvailable = context.select<AuthService, bool>(
      (s) => s.isAppleAvailable,
    );

    return Scaffold(
      backgroundColor: black,
      body: AppTheme.background(
        context,
        child: SafeArea(
          // Center + a single outer scroll view: the Row shrink-wraps to its
          // content and sits vertically centred, and only scrolls if the
          // content is ever taller than the viewport.
          //
          // The scroll view must stay OUTSIDE the Row. Placed inside a column,
          // it expands to the full height and top-anchors its child, which is
          // what pushed this layout to the top of the screen.
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 16, 40, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: brand block
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // No Flexible here: a flexible child forces the Column
                        // to consume the full height, which also broke
                        // centring.
                        AppTheme.logo(
                          size: (screenSize.height * 0.42).clamp(96.0, 220.0),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sign in to save your scores',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  // Right: sign-in options.
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTheme.solidButton(
                          label: _busy ? 'PLEASE WAIT…' : 'SIGN IN WITH GOOGLE',
                          color: blue,
                          fontSize: 18,
                          leading: const Text(
                            '🌐',
                            style: TextStyle(fontSize: 20),
                          ),
                          onTap: _busy
                              ? null
                              : () => _handle(
                                  () => context
                                      .read<AuthService>()
                                      .signInWithGoogle(),
                                ),
                        ),
                        // Apple's HIG mandates the official button; hide it
                        // entirely where Sign in with Apple is unsupported.
                        if (appleAvailable) ...[
                          const SizedBox(height: 16),
                          SignInWithAppleButton(
                            height: 60,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(AppTheme.radius),
                            ),
                            onPressed: _busy
                                ? () {}
                                : () => _handle(
                                    () => context
                                        .read<AuthService>()
                                        .signInWithApple(),
                                  ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        AppTheme.outlineButton(
                          label: '▶  PLAY AS GUEST',
                          color: green,
                          fontSize: 16,
                          onTap: _busy
                              ? null
                              : () {
                                  developer.log(
                                    'Continuing as guest',
                                    name: 'LoginScreen',
                                  );
                                  AppUtils.popAndPushNamed(
                                    context,
                                    Routes.main,
                                  );
                                },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Signing in is optional — your scores are only saved '
                          'when you do.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
