import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memorygame/config/app_theme.dart';
import 'package:memorygame/config/milestones.dart';
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

  /// Selected stats tab. VS Computer is the default.
  String _selectedMode = GameModes.vsCpu;

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
                final email = (data?['email'] as String?) ?? (user.email ?? '');
                final photoUrl =
                    (data?['photoUrl'] as String?) ?? user.photoURL;
                final loading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    data == null;

                return Row(
                  // Stretch so both panels fill the available height; each
                  // scrolls internally rather than overflowing. Landscape
                  // leaves little vertical room, and the stats panel grows
                  // with the milestone row + tabs + table.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      child: _statsPanel(
                        stats: stats,
                        loading: loading,
                        // Raw document: the table needs a per-difficulty best
                        // streak for each row, not just the mode total.
                        data: data,
                      ),
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
      child: SingleChildScrollView(
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
            ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
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

  Widget _statsPanel({
    required ProfileStats stats,
    required bool loading,
    required Map<String, dynamic>? data,
  }) {
    // Scoped view of whichever tab is selected.
    final modeStats = stats.mode(_selectedMode);

    int streakFor(String difficulty) =>
        ProfileService.bestStreakFor(data, _selectedMode, difficulty);

    // Headline: the best milestone reached anywhere in this mode, whichever
    // difficulty earned it. Deliberately not attributed to a difficulty — the
    // per-difficulty figures are the table's job.
    final bestStreak = ProfileService.bestStreakForMode(data, _selectedMode);
    // Live run: drives the progress bar. Only one difficulty can hold a run at
    // a time, so this is that run. Drops to zero on a loss, and switching
    // difficulty ends it.
    final currentStreak = ProfileService.currentStreakForMode(
      data,
      _selectedMode,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: AppTheme.panel(borderColor: pink),
      child: SingleChildScrollView(
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
            const SizedBox(height: 8),
            _modeTabs(),
            const SizedBox(height: 10),
            // Per mode. A run may span difficulties, so bestDifficulty is
            // where the record was set, not a boundary the run sat inside.
            _milestonePanel(bestStreak, currentStreak),
            const SizedBox(height: 10),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator(color: cyan)),
              )
            else ...[
              _statsHeaderRow(),
              const SizedBox(height: 6),
              _statsRow(
                'Easy',
                Difficulties.easy,
                modeStats,
                green,
                streakFor(Difficulties.easy),
              ),
              _statsRow(
                'Medium',
                Difficulties.medium,
                modeStats,
                yellow,
                streakFor(Difficulties.medium),
              ),
              _statsRow(
                'Hard',
                Difficulties.hard,
                modeStats,
                lightRed,
                streakFor(Difficulties.hard),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: lightGrey, thickness: 2, height: 2),
              ),
              // Total streak is the MAX of the three, not a sum.
              _totalRow(modeStats, bestStreak),
              // Only meaningful on the two-player tab; the P1 assumption does
              // not apply to VS CPU games.
              if (_selectedMode == GameModes.twoPlayer) ...[
                const SizedBox(height: 14),
                const Text(
                  'In two-player games, your record is tracked as Player 1.',
                  style: AppTheme.muted,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// [streak] as a milestone figure for display: the tier it reached, or a
  /// dash below the first tier. Never the raw running total — the profile
  /// reports milestones (3, 5, 7, 10, 15, 20), not arbitrary numbers.
  static String _milestoneLabel(int streak) {
    final snapped = Milestones.snap(streak);
    return snapped == 0 ? '—' : '$snapped';
  }

  /// Rank card for the SELECTED mode: the best milestone reached across every
  /// difficulty, and progress toward the next one.
  ///
  /// VS CPU and two-player keep entirely separate records. Within a mode this
  /// card is deliberately difficulty-agnostic — per-difficulty figures belong
  /// to the table below it.
  ///
  /// [bestStreak] is the all-time record and sets the earned rank, so a loss
  /// never demotes you. [currentStreak] is the live run: it drives the bar,
  /// drops to zero on a loss, and ends when the player switches difficulty.
  Widget _milestonePanel(int bestStreak, int currentStreak) {
    final milestone = Milestones.highestFor(bestStreak);
    final reached = milestone != null;
    // The target is the milestone above the rank already EARNED, not above the
    // live run. With Fire (3) earned and a run of 1, the goal is Lightning (5)
    // — measuring from the run would point back at Fire, a rank already held.
    //
    // Null once the top tier is earned; the card shows "Highest rank reached"
    // in place of the bar in that case.
    final next = Milestones.nextFor(bestStreak);
    // Clamped so a stale value can never overflow the bar.
    final progress = next == null
        ? 0.0
        : (currentStreak / next.at).clamp(0.0, 1.0);
    final remaining = next == null
        ? 0
        : (next.at - currentStreak).clamp(0, next.at);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: reached ? lightBlueColor : imageBg,
        borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radius)),
        border: Border.all(
          color: reached ? cyan : lightGrey,
          width: AppTheme.panelBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rank title only. The difficulty is intentionally absent: this is
          // the best across every difficulty in the mode, so naming one would
          // misrepresent it.
          Row(
            children: [
              Text(
                reached ? milestone.icon : '🏅',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reached ? milestone.title : 'No milestone yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: reached ? blue : textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: the streak itself.
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Best streak:',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.muted,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          // A dash, not 0, below the first tier: the player may
                          // well have won games, just not reached a milestone.
                          '🔥 ${_milestoneLabel(bestStreak)}',
                          style: const TextStyle(
                            color: black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Text(
                        'wins in a row',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.muted,
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(
                  color: lightGrey,
                  thickness: 2,
                  width: 20,
                ),
                // Right: next rank and progress toward it.
                Expanded(
                  flex: 6,
                  child: next == null
                      ? const Center(
                          child: Text(
                            '🌍 Highest rank reached',
                            style: TextStyle(
                              color: blue,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Next rank:', style: AppTheme.muted),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  next.icon,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    next.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: blue,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Win $remaining more '
                              '${remaining == 1 ? "game" : "games"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.muted,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(6),
                                    ),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 10,
                                      backgroundColor: white,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            green,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$currentStreak / ${next.at}',
                                  style: const TextStyle(
                                    color: black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Two tabs, styled with the same palette and shape language as the Main and
  /// Difficulty screen buttons rather than a default Material TabBar.
  Widget _modeTabs() {
    return Row(
      children: [
        _modeTab('VS Computer', GameModes.vsCpu),
        const SizedBox(width: 10),
        _modeTab('Two Player', GameModes.twoPlayer),
      ],
    );
  }

  Widget _modeTab(String label, String mode) {
    final selected = _selectedMode == mode;
    return Expanded(
      child: InkWell(
        onTap: selected ? null : () => setState(() => _selectedMode = mode),
        borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radius)),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            // Selected mirrors the Main screen's solid buttons (filled + gold
            // border); unselected mirrors the Difficulty screen's outlined
            // buttons (white fill + coloured border).
            color: selected ? blue : white,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppTheme.radius),
            ),
            border: Border.all(
              color: selected ? yellow : lightGrey,
              width: selected
                  ? AppTheme.solidButtonBorderWidth
                  : AppTheme.panelBorderWidth,
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? white : textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsHeaderRow() {
    const style = TextStyle(
      color: textColor,
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );
    // scaleDown rather than ellipsis: five columns in a landscape half-panel
    // is tight, and "Win streak" is the longest label. Shrinking keeps the
    // header readable where clipping to "Win stre…" would not.
    Widget cell(String label) => Expanded(
      flex: 2,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, textAlign: TextAlign.center, style: style),
      ),
    );

    return Row(
      children: [
        const Expanded(flex: 3, child: Text('', style: style)),
        cell('Wins'),
        cell('Losses'),
        cell('Win rate'),
        cell('Win streak'),
      ],
    );
  }

  Widget _statsRow(
    String label,
    String key,
    ModeStats stats,
    Color accent,
    int streak,
  ) {
    final rate = stats.winRate(key);
    final played = stats.played(key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
          // Same treatment for the streak: a dash when this difficulty has
          // never been played, rather than a misleading 0. Shown as the
          // milestone reached, so it matches the rank card above.
          Expanded(
            flex: 2,
            child: _numberCell(played == 0 ? '—' : _milestoneLabel(streak)),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(ModeStats stats, int bestStreak) {
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
        Expanded(
          flex: 2,
          child: _numberCell(
            stats.totalPlayed == 0 ? '—' : _milestoneLabel(bestStreak),
            bold: true,
          ),
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
            // Shared by the Save button and the keyboard's done action, so
            // the user can submit without reaching past the keyboard.
            Future<void> submit() async {
              if (saving) return;
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
              // Keep the user on the edit dialog with their text intact
              // rather than discarding it.
              setDialogState(() {
                saving = false;
                error = outcome.message ?? 'Your name could not be saved.';
              });
            }

            return AppTheme.dialog(
              context: dialogContext,
              emoji: '✏️',
              title: 'Edit Name',
              children: [
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  maxLength: 30,
                  autofocus: true,
                  enabled: !saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  style: AppTheme.body,
                  decoration: InputDecoration(
                    counterText: '',
                    isDense: true,
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
                        onTap: saving ? null : submit,
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
