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

/// Game-mode keys for the stats map. Records are split so a VS CPU result and
/// a two-player result never land in the same counter.
class GameModes {
  const GameModes._();

  static const vsCpu = 'vsCpu';
  static const twoPlayer = 'twoPlayer';

  static const all = <String>[vsCpu, twoPlayer];

  static String fromIsVsCpu(bool isVsCpu) => isVsCpu ? vsCpu : twoPlayer;
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

  /// Guards against firing the same lazy migration repeatedly while an earlier
  /// attempt is still in flight (snapshots can arrive faster than the write).
  final Set<String> _migrationsInFlight = <String>{};

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(usersCollection).doc(uid);

  /// Zeroed stats block written only when a document is first created, so that
  /// later FieldValue.increment() calls always have a field to land on.
  ///
  /// Twelve counters: two modes x three difficulties x wins/losses.
  static Map<String, dynamic> _zeroedStats() => <String, dynamic>{
    for (final mode in GameModes.all)
      mode: <String, dynamic>{
        for (final d in Difficulties.all)
          d: <String, dynamic>{'wins': 0, 'losses': 0},
      },
  };

  /// Best win streak per mode, zeroed at document creation.
  ///
  /// Streaks are per mode in practice: changing mode is only possible via the
  /// Main screen, and every route back there calls restartGame(true), which
  /// zeroes the streak counters. A run of consecutive wins therefore always
  /// belongs to exactly one mode.
  static Map<String, dynamic> _zeroedBestStreak() => <String, dynamic>{
    for (final mode in GameModes.all) mode: 0,
  };

  /// Reads the best streak for [mode] out of a profile document, tolerating
  /// the pre-split shape where `bestStreak` was a single integer.
  static int bestStreakFor(Map<String, dynamic>? data, String mode) {
    final raw = data?['bestStreak'];
    if (raw is Map) {
      final value = raw[mode];
      return value is num ? value.toInt() : 0;
    }
    // Legacy single-int shape: it could only have come from VS CPU or
    // two-player play, and mode was not recorded. Attribute it to VS CPU,
    // matching how legacy stats are migrated.
    if (raw is num) {
      return mode == GameModes.vsCpu ? raw.toInt() : 0;
    }
    return 0;
  }

  // -------------------------------------------------------------- migration

  /// True when `stats` still carries the ORIGINAL six-counter shape, i.e. the
  /// difficulty keys sit directly under `stats` rather than under a mode.
  ///
  /// Detection is based purely on the presence of those legacy keys, NOT on
  /// the absence of `vsCpu`. That matters: a document can legitimately hold
  /// both at once if recordResult's dot-path increment created `stats.vsCpu.*`
  /// on a document that had not been migrated yet. Keying off the legacy keys
  /// means such a document is still recognised and merged rather than being
  /// mistaken for an already-migrated one (which would strand the old totals).
  static bool _isLegacyStats(Map<String, dynamic>? stats) {
    if (stats == null) return false;
    return Difficulties.all.any((d) => stats[d] is Map);
  }

  /// Converts a legacy stats map to the new mode-split shape.
  ///
  /// The old counters were recorded before modes were distinguished; they are
  /// attributed to `vsCpu`. Any values already present under `vsCpu` or
  /// `twoPlayer` are preserved and added to, so an interleaved increment is
  /// never lost.
  ///
  /// The returned map contains ONLY the new keys. Because the caller writes it
  /// with `update({'stats': ...})`, which replaces the whole field, the legacy
  /// difficulty keys disappear — which is what makes the operation idempotent.
  static Map<String, dynamic> migrateLegacyStats(Map<String, dynamic> stats) {
    final existingVsCpu = stats[GameModes.vsCpu];
    final existingTwoPlayer = stats[GameModes.twoPlayer];

    return <String, dynamic>{
      GameModes.vsCpu: <String, dynamic>{
        for (final d in Difficulties.all)
          d: <String, dynamic>{
            'wins':
                _readCounter(stats[d], 'wins') +
                _readCounter(_blockFor(existingVsCpu, d), 'wins'),
            'losses':
                _readCounter(stats[d], 'losses') +
                _readCounter(_blockFor(existingVsCpu, d), 'losses'),
          },
      },
      GameModes.twoPlayer: <String, dynamic>{
        for (final d in Difficulties.all)
          d: <String, dynamic>{
            'wins': _readCounter(_blockFor(existingTwoPlayer, d), 'wins'),
            'losses': _readCounter(_blockFor(existingTwoPlayer, d), 'losses'),
          },
      },
    };
  }

  /// True when the document still carries any pre-split shape:
  /// six-counter `stats`, or `bestStreak` as a single integer.
  static bool _needsMigration(Map<String, dynamic> data) =>
      _isLegacyStats(data['stats'] as Map<String, dynamic>?) ||
      data['bestStreak'] is num;

  /// The fields that must be rewritten to bring a document up to date.
  /// Only the keys that actually need changing are included.
  static Map<String, dynamic> _migratedFields(Map<String, dynamic> data) {
    final out = <String, dynamic>{};

    final stats = data['stats'] as Map<String, dynamic>?;
    if (_isLegacyStats(stats)) {
      out['stats'] = migrateLegacyStats(stats!);
    }

    final bestStreak = data['bestStreak'];
    if (bestStreak is num) {
      out['bestStreak'] = <String, dynamic>{
        GameModes.vsCpu: bestStreak.toInt(),
        GameModes.twoPlayer: 0,
      };
    }

    return out;
  }

  /// Writes migrated fields back once. Failures are logged, never surfaced:
  /// the caller has already been handed a locally-migrated view, so the UI is
  /// correct either way and the write simply retries on the next snapshot.
  Future<void> _persistMigration(
    String uid,
    Map<String, dynamic> migratedFields,
  ) async {
    if (migratedFields.isEmpty) return;
    if (_migrationsInFlight.contains(uid)) return;
    _migrationsInFlight.add(uid);
    try {
      // `update` replaces each named field wholesale, dropping the legacy
      // difficulty keys / scalar bestStreak. A merge-set would have left the
      // old keys behind.
      await _userDoc(uid).update(<String, dynamic>{
        ...migratedFields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      developer.log(
        'Migrated ${migratedFields.keys.join(", ")} for uid=$uid',
        name: 'ProfileService',
      );
    } on FirebaseException catch (e, st) {
      developer.log(
        'Stats migration failed for uid=$uid: code=${e.code} message=${e.message}',
        name: 'ProfileService',
        error: e,
        stackTrace: st,
      );
    } finally {
      _migrationsInFlight.remove(uid);
    }
  }

  // ------------------------------------------------------------------ reads

  /// Live stream of the signed-in user's profile document.
  ///
  /// If the document still has the legacy stats shape it is migrated in place
  /// (written back once) and the emitted value is converted locally, so the UI
  /// shows correct numbers immediately rather than waiting for the write.
  ///
  /// Errors are converted into a null emission rather than being allowed to
  /// escape — an unhandled stream error inside a StreamBuilder renders a red
  /// error screen to the user.
  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    return _userDoc(uid)
        .snapshots()
        .map((snap) {
          final data = snap.data();
          if (data == null) return null;

          if (_needsMigration(data)) {
            final migrated = _migratedFields(data);
            // Fire and forget; guarded against repeat runs.
            _persistMigration(uid, migrated);
            // Hand back a locally-migrated view so the UI is correct now.
            return <String, dynamic>{...data, ...migrated};
          }
          return data;
        })
        .handleError((Object error, StackTrace stack) {
          developer.log(
            'watchProfile failed for uid=$uid',
            name: 'ProfileService',
            error: error,
            stackTrace: stack,
          );
        });
  }

  // ----------------------------------------------------------------- writes

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
          'bestStreak': _zeroedBestStreak(),
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

  /// Records one finished game against the correct mode and difficulty.
  ///
  /// Fails silently by design: a game ending must never interrupt the user with
  /// an error. Firestore queues writes while offline and replays them on
  /// reconnect, so transient failures usually resolve themselves.
  ///
  /// Returns silently when nobody is signed in.
  /// [currentStreak] is the signed-in player's consecutive-win count AFTER
  /// this game, used to maintain `bestStreak`. Ignored on a loss.
  Future<void> recordResult({
    required bool isVsCpu,
    required String difficulty,
    required bool won,
    int currentStreak = 0,
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
    final mode = GameModes.fromIsVsCpu(isVsCpu);
    final field = 'stats.$mode.$difficulty.${won ? 'wins' : 'losses'}';

    // Dot-path + increment: atomic server-side, and safe to queue offline.
    final payload = <String, dynamic>{
      field: FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await ref.update(payload);
      if (won) await _maybeUpdateBestStreak(ref, mode, currentStreak);
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
            'bestStreak': _zeroedBestStreak(),
          'stats': _zeroedStats(),
          }, SetOptions(merge: true));
          await ref.update(payload);
          if (won) await _maybeUpdateBestStreak(ref, mode, currentStreak);
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

  /// Raises `bestStreak` when [streak] beats the stored value.
  ///
  /// Firestore has no server-side "max", so this needs a read — hence a
  /// transaction rather than the dot-path increment used for the counters.
  /// The trade-off is that transactions require connectivity: unlike the
  /// win/loss write, this one is NOT queued offline. It is best-effort and
  /// catches up on the next win made while online.
  ///
  /// Never surfaces an error — a game ending must not interrupt the player.
  Future<void> _maybeUpdateBestStreak(
    DocumentReference<Map<String, dynamic>> ref,
    String mode,
    int streak,
  ) async {
    if (streak <= 0) return;
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final current = bestStreakFor(snap.data(), mode);
        if (streak <= current) return;
        // Dot path so the other mode's record is untouched.
        tx.update(ref, <String, dynamic>{
          'bestStreak.$mode': streak,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e, st) {
      developer.log(
        'bestStreak update failed: code=${e.code} message=${e.message}',
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

  // ---------------------------------------------------------------- helpers

  static Map<String, dynamic>? _blockFor(Object? modeMap, String difficulty) {
    if (modeMap is Map) {
      final block = modeMap[difficulty];
      if (block is Map) return Map<String, dynamic>.from(block);
    }
    return null;
  }

  static int _readCounter(Object? block, String key) {
    if (block is Map) {
      final v = block[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return 0;
  }

  static String? _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return c.trim();
    }
    return null;
  }
}

/// Read model for the whole stats block. Derived values are computed here
/// rather than stored, so nothing can drift out of sync.
class ProfileStats {
  const ProfileStats(this._raw);

  final Map<String, dynamic>? _raw;

  /// Scoped view of a single game mode ('vsCpu' or 'twoPlayer').
  ModeStats mode(String mode) {
    final block = _raw?[mode];
    return ModeStats(block is Map ? Map<String, dynamic>.from(block) : null);
  }
}

/// Read model for one mode's three difficulties.
class ModeStats {
  const ModeStats(this._raw);

  final Map<String, dynamic>? _raw;

  int wins(String difficulty) => _value(difficulty, 'wins');

  int losses(String difficulty) => _value(difficulty, 'losses');

  int played(String difficulty) => wins(difficulty) + losses(difficulty);

  int get totalWins =>
      Difficulties.all.fold(0, (running, d) => running + wins(d));

  int get totalLosses =>
      Difficulties.all.fold(0, (running, d) => running + losses(d));

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
