import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memorygame/config/app_theme.dart';
import 'package:memorygame/network/routes.dart';
import 'package:memorygame/services/auth_service.dart';
import 'package:memorygame/services/profile_service.dart';
import 'package:memorygame/utils/app_utils.dart';
import 'package:memorygame/utils/custom_colors.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    // Signed out (e.g. deletion completed while this screen was open).
    if (user == null) {
      return Scaffold(
        backgroundColor: black,
        body: AppTheme.background(
          context,
          child: Center(
            child: SizedBox(
              width: 260,
              child: AppTheme.solidButton(
                label: 'SIGN IN',
                color: blue,
                onTap: () =>
                    AppUtils.popAndPushNamed(context, Routes.loginScreen),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: black,
      body: AppTheme.background(
        context,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 16, 30, 16),
            child: StreamBuilder<Map<String, dynamic>?>(
              stream: auth.profileService.watchProfile(user.uid),
              builder: (context, snapshot) {
                final data = snapshot.data;
                final stats = ProfileStats(
                  data?['stats'] as Map<String, dynamic>?,
                );
                final displayName =
                    (data?['displayName'] as String?)?.trim().isNotEmpty == true
                    ? data!['displayName'] as String
                    : (user.displayName ?? 'Player');
                final email =
                    (data?['email'] as String?) ?? (user.email ?? '');
                final photoUrl =
                    (data?['photoUrl'] as String?) ?? user.photoURL;
                final loading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    data == null;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _identityPanel(
                        user: user,
                        displayName: displayName,
                        email: email,
                        photoUrl: photoUrl,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 6,
                      child: _statsPanel(stats: stats, loading: loading),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- left panel

  Widget _identityPanel({
    required User user,
    required String displayName,
    required String email,
    required String? photoUrl,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: AppTheme.panel(borderColor: cyan),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _avatar(photoUrl, displayName),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTheme.outlineButton(
            label: '✏️  EDIT NAME',
            color: blue,
            height: 46,
            onTap: _busy ? null : () => _showEditNameDialog(displayName),
          ),
          const SizedBox(height: 10),
          AppTheme.outlineButton(
            label: '🏠  BACK TO MENU',
            color: green,
            height: 46,
            onTap: _busy
                ? null
                : () => AppUtils.popAndPushNamed(context, Routes.main),
          ),
          const SizedBox(height: 10),
          AppTheme.outlineButton(
            label: '🚪  SIGN OUT',
            color: grey,
            height: 46,
            onTap: _busy ? null : _handleSignOut,
          ),
          const SizedBox(height: 14),
          // Account deletion: plainly visible, red, per App Store 5.1.1.
          InkWell(
            onTap: _busy ? null : _showDeleteAccountDialog,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Delete account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? photoUrl, String displayName) {
    final initials = AppUtils.getInitials(displayName);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: lightBlueColor,
        shape: BoxShape.circle,
        border: Border.all(color: cyan, width: 3),
        image: (photoUrl != null && photoUrl.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(photoUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: (photoUrl == null || photoUrl.isEmpty)
          ? Text(
              initials.isEmpty ? '?' : initials,
              style: const TextStyle(
                color: blue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  // ------------------------------------------------------------ right panel

  Widget _statsPanel({required ProfileStats stats, required bool loading}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: AppTheme.panel(borderColor: pink),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🏆  YOUR RECORD',
            style: TextStyle(
              color: lightRed,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: CircularProgressIndicator(color: cyan),
              ),
            )
          else ...[
            _statsHeaderRow(),
            const SizedBox(height: 6),
            _statsRow('Easy', Difficulties.easy, stats, green),
            _statsRow('Medium', Difficulties.medium, stats, yellow),
            _statsRow('Hard', Difficulties.hard, stats, lightRed),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: lightGrey, thickness: 2, height: 2),
            ),
            _totalRow(stats),
            const SizedBox(height: 14),
            const Text(
              'In two-player games, your record is tracked as Player 1.',
              style: AppTheme.muted,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsHeaderRow() {
    const style = TextStyle(
      color: textColor,
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );
    return Row(
      children: const [
        Expanded(flex: 3, child: Text('', style: style)),
        Expanded(
          flex: 2,
          child: Text('Wins', textAlign: TextAlign.center, style: style),
        ),
        Expanded(
          flex: 2,
          child: Text('Losses', textAlign: TextAlign.center, style: style),
        ),
        Expanded(
          flex: 2,
          child: Text('Win rate', textAlign: TextAlign.center, style: style),
        ),
      ],
    );
  }

  Widget _statsRow(
    String label,
    String key,
    ProfileStats stats,
    Color accent,
  ) {
    final rate = stats.winRate(key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(flex: 2, child: _numberCell('${stats.wins(key)}')),
          Expanded(flex: 2, child: _numberCell('${stats.losses(key)}')),
          // Dash rather than NaN when no games have been played yet.
          Expanded(flex: 2, child: _numberCell(rate == null ? '—' : '$rate%')),
        ],
      ),
    );
  }

  Widget _totalRow(ProfileStats stats) {
    final rate = stats.totalWinRate;
    return Row(
      children: [
        const Expanded(
          flex: 3,
          child: Text(
            'Total',
            style: TextStyle(
              color: black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(flex: 2, child: _numberCell('${stats.totalWins}', bold: true)),
        Expanded(
          flex: 2,
          child: _numberCell('${stats.totalLosses}', bold: true),
        ),
        Expanded(
          flex: 2,
          child: _numberCell(rate == null ? '—' : '$rate%', bold: true),
        ),
      ],
    );
  }

  Widget _numberCell(String text, {bool bold = false}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: black,
        fontSize: 16,
        fontWeight: bold ? FontWeight.bold : FontWeight.w600,
      ),
    );
  }

  // ---------------------------------------------------------------- actions

  Future<void> _handleSignOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Any game in progress is simply abandoned; no result is recorded.
      await context.read<AuthService>().signOut();
      if (!mounted) return;
      AppUtils.popAndPushNamed(context, Routes.loginScreen);
    } on FirebaseAuthException catch (e, st) {
      developer.log(
        'Sign-out failed: code=${e.code}',
        name: 'ProfileScreen',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      _showMessage('⚠️', 'Sign-out Failed', 'Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showEditNameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    // Kept outside the dialog so the typed text survives a failed save.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool saving = false;
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AppTheme.dialog(
              context: dialogContext,
              emoji: '✏️',
              title: 'Edit Name',
              children: [
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  maxLength: 30,
                  textCapitalization: TextCapitalization.words,
                  style: AppTheme.body,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Your display name',
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.dialogButtonRadius,
                      ),
                      borderSide: const BorderSide(color: lightGrey, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.dialogButtonRadius,
                      ),
                      borderSide: const BorderSide(color: cyan, width: 2),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: red,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppTheme.dialogButton(
                        label: 'Cancel',
                        color: lightRed,
                        onTap: saving
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTheme.dialogButton(
                        label: saving ? 'Saving…' : 'Save',
                        color: blue,
                        onTap: saving
                            ? null
                            : () async {
                                setDialogState(() {
                                  saving = true;
                                  error = null;
                                });
                                final outcome = await context
                                    .read<AuthService>()
                                    .updateDisplayName(controller.text);
                                if (!dialogContext.mounted) return;
                                if (outcome.isSuccess) {
                                  Navigator.of(dialogContext).pop();
                                  return;
                                }
                                // Keep the user on the edit dialog with their
                                // text intact rather than discarding it.
                                setDialogState(() {
                                  saving = false;
                                  error = outcome.message ??
                                      'Your name could not be saved.';
                                });
                              },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppTheme.dialog(
          context: dialogContext,
          emoji: '⚠️',
          title: 'Delete Account',
          children: [
            const SizedBox(height: 10),
            const Text(
              'This permanently deletes your account and erases all of your '
              'scores. This cannot be undone.',
              textAlign: TextAlign.center,
              style: AppTheme.body,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppTheme.dialogButton(
                    label: 'Cancel',
                    color: blue,
                    onTap: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTheme.dialogButton(
                    label: 'Delete',
                    color: red,
                    onTap: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await _performDeletion(allowReauth: true);
  }

  Future<void> _performDeletion({required bool allowReauth}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final auth = context.read<AuthService>();
      final outcome = await auth.deleteAccount();
      if (!mounted) return;

      if (outcome.isSuccess) {
        AppUtils.popAndPushNamed(context, Routes.loginScreen);
        return;
      }

      if (outcome.requiresReauth && allowReauth) {
        // Expected path, not an error: the session is stale. Send the user
        // back through the sign-in sheet, then continue the deletion.
        final reauth = await auth.reauthenticate();
        if (!mounted) return;

        if (reauth.isCancelled) {
          // Backed out of re-authentication; leave the account intact.
          return;
        }
        if (reauth.isFailure) {
          _showMessage(
            '⚠️',
            'Delete Failed',
            reauth.message ?? 'Please try again.',
          );
          return;
        }
        setState(() => _busy = false);
        await _performDeletion(allowReauth: false);
        return;
      }

      _showMessage(
        '⚠️',
        'Delete Failed',
        outcome.message ??
            'Your account could not be deleted. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String emoji, String title, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppTheme.dialog(
          context: dialogContext,
          emoji: emoji,
          title: title,
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
}
