import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memorygame/config/auth_config.dart';

/// Valid difficulty keys for the stats map. These mirror the existing
/// difficultyMode values held in GameProvider (1 / 2 / 3).
class Difficulties {
  const Difficulties._();

  static const easy = 'easy';
  static const medium = 'medium';
  static const hard = 'hard';

  static const all = <String>[easy, medium, hard];

  /// Maps the existing GameProvider.difficultyMode integer onto a stats key.
  /// Falls back to `easy` so an unexpected value can never drop a result.
  static String fromMode(int mode) {
    switch (mode) {
      case 2:
        return medium;
      case 3:
        return hard;
      case 1:
      default:
        return easy;
    }
  }
}

/// All Cloud Firestore access for user profiles and score tracking.
///
/// Widgets never touch Firestore directly — they go through this class.
class ProfileService {
  ProfileService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(usersCollection).doc(uid);

  /// Zeroed stats block written only when a document is first created, so that
  /// later FieldValue.increment() calls always have a field to land on.
  static Map<String, dynamic> _zeroedStats() => <String, dynamic>{
    for (final d in Difficulties.all)
      d: <String, dynamic>{'wins': 0, 'losses': 0},
  };

  /// Live stream of the signed-in user's profile document.
  ///
  /// Errors are converted into a null emission rather than being allowed to
  /// escape — an unhandled stream error inside a StreamBuilder renders a red
  /// error screen to the user.
  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    return _userDoc(uid)
        .snapshots()
        .map((snap) => snap.data())
        .handleError((Object error, StackTrace stack) {
          developer.log(
            'watchProfile failed for uid=$uid',
            name: 'ProfileService',
            error: error,
            stackTrace: stack,
          );
        });
  }

  /// Creates or refreshes users/{uid} on every sign-in.
  ///
  /// On first creation the full document (including zeroed stats) is written.
  /// On subsequent sign-ins only the profile fields are merged — the `stats`
  /// key is deliberately omitted so a returning user's scores are never reset.
  ///
  /// [displayName] is only written when non-empty. Apple supplies a name on the
  /// first authorization only, so a later null must never clobber a stored one.
  Future<void> upsertOnSignIn({
    required User user,
    required String provider,
    String? displayName,
    String? email,
    String? photoUrl,
  }) async {
    final ref = _userDoc(user.uid);
    final resolvedName = _firstNonEmpty([displayName, user.displayName]);
    final resolvedEmail = _firstNonEmpty([email, user.email]);
    final resolvedPhoto = _firstNonEmpty([photoUrl, user.photoURL]);

    try {
      final snap = await ref.get();

      if (!snap.exists) {
        await ref.set(<String, dynamic>{
          'displayName': resolvedName ?? 'Player',
          'email': resolvedEmail ?? '',
          'photoUrl': resolvedPhoto,
          'provider': provider,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'stats': _zeroedStats(),
        });
        return;
      }

      // Returning user: merge profile fields only, never `stats`.
      final update = <String, dynamic>{
        'provider': provider,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Guarded so a null from a repeat Apple sign-in cannot erase the name.
      if (resolvedName != null) update['displayName'] = resolvedName;
      if (resolvedEmail != null) update['email'] = resolvedEmail;
      if (resolvedPhoto != null) update['photoUrl'] = resolvedPhoto;

      await ref.set(update, SetOptions(merge: true));
    } on FirebaseException catch (e, st) {
      developer.log(
        'upsertOnSignIn failed: code=${e.code} message=${e.message}',
        name: 'ProfileService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Records one finished game.
  ///
  /// Fails silently by design: a game ending must never interrupt the user with
  /// an error. Firestore queues writes while offline and replays them on
  /// reconnect, so transient failures usually resolve themselves.
  ///
  /// Returns silently when nobody is signed in.
  Future<void> recordResult({
    required String difficulty,
    required bool won,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (!Difficulties.all.contains(difficulty)) {
      developer.log(
        'recordResult ignored unknown difficulty="$difficulty"',
        name: 'ProfileService',
      );
      return;
    }

    final ref = _userDoc(user.uid);
    final field = 'stats.$difficulty.${won ? 'wins' : 'losses'}';

    // Dot-path + increment: atomic server-side, and safe to queue offline.
    final payload = <String, dynamic>{
      field: FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await ref.update(payload);
    } on FirebaseException catch (e, st) {
      if (e.code == 'not-found') {
        // Document missing (e.g. deleted on another device). Recreate the
        // skeleton and retry once so the result is not lost.
        try {
          await ref.set(<String, dynamic>{
            'displayName': user.displayName ?? 'Player',
            'email': user.email ?? '',
            'photoUrl': user.photoURL,
            'provider': 'unknown',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'stats': _zeroedStats(),
          }, SetOptions(merge: true));
          await ref.update(payload);
        } on FirebaseException catch (e2, st2) {
          developer.log(
            'recordResult retry failed: code=${e2.code} message=${e2.message}',
            name: 'ProfileService',
            error: e2,
            stackTrace: st2,
          );
        }
        return;
      }
      developer.log(
        'recordResult failed: code=${e.code} message=${e.message}',
        name: 'ProfileService',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Updates the stored display name. Firestore is the source of truth for
  /// display; the caller also updates the FirebaseAuth profile.
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    await _userDoc(uid).set(<String, dynamic>{
      'displayName': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Permanently removes the profile document. Called during account deletion,
  /// before the FirebaseAuth user is deleted, so no orphaned data remains.
  Future<void> deleteProfile(String uid) async {
    await _userDoc(uid).delete();
  }

  static String? _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return c.trim();
    }
    return null;
  }
}

/// Read model for the stats block, with all derived values computed here
/// rather than stored, so nothing can drift out of sync.
class ProfileStats {
  const ProfileStats(this._raw);

  final Map<String, dynamic>? _raw;

  int wins(String difficulty) => _value(difficulty, 'wins');

  int losses(String difficulty) => _value(difficulty, 'losses');

  int played(String difficulty) => wins(difficulty) + losses(difficulty);

  int get totalWins =>
      Difficulties.all.fold(0, (running, d) => running +wins(d));

  int get totalLosses =>
      Difficulties.all.fold(0, (running, d) => running +losses(d));

  int get totalPlayed => totalWins + totalLosses;

  /// Win rate as a whole percentage, or null when no games have been played.
  /// Callers render null as a dash rather than NaN.
  int? winRate(String difficulty) {
    final p = played(difficulty);
    if (p == 0) return null;
    return ((wins(difficulty) / p) * 100).round();
  }

  int? get totalWinRate {
    if (totalPlayed == 0) return null;
    return ((totalWins / totalPlayed) * 100).round();
  }

  int _value(String difficulty, String key) {
    final block = _raw?[difficulty];
    if (block is Map) {
      final v = block[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return 0;
  }
}
