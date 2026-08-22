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

  /// Best win streak per mode AND difficulty, zeroed at document creation.
  ///
  /// A run can span difficulties, so the peak of a run is recorded against
  /// whichever difficulty was being played at the moment it was reached. The
  /// headline figure is therefore always a MAX across difficulties
  /// ([bestStreakForMode]), never a sum — that max is exactly the true
  /// lifetime best, since every new peak is written as it happens.
  static Map<String, dynamic> _zeroedBestStreak() => <String, dynamic>{
    for (final mode in GameModes.all)
      mode: <String, dynamic>{for (final d in Difficulties.all) d: 0},
  };

  /// The streak currently in progress, per mode.
  ///
  /// Deliberately NOT per difficulty: this counts consecutive wins in a mode
  /// regardless of which difficulty each was played on, so a run continues
  /// when the player switches difficulty. Splitting it per difficulty would
  /// leave stale non-zero values on the ones not being played.
  ///
  /// Maintained entirely by [recordResult] via a server-side increment; the
  /// game provider's in-memory streak is separate and resets per session.
  static Map<String, dynamic> _zeroedCurrentStreak() => <String, dynamic>{
    for (final mode in GameModes.all) mode: 0,
  };

  /// Live streak for [mode]. Absent reads as 0, so no migration is needed for
  /// documents created before this field existed.
  static int currentStreakFor(Map<String, dynamic>? data, String mode) {
    final raw = data?['currentStreak'];
    if (raw is Map) {
      final value = raw[mode];
      if (value is num) return value.toInt();
    }
    return 0;
  }

  /// Best streak for one [mode] + [difficulty].
  ///
  /// Tolerates both older shapes: a bare integer (before modes existed) and
  /// mode -> int (before difficulties existed). Both are attributed the same
  /// way the lazy migration attributes them, so the UI reads correctly even
  /// before the write-back lands.
  static int bestStreakFor(
    Map<String, dynamic>? data,
    String mode,
    String difficulty,
  ) {
    final raw = data?['bestStreak'];

    // Current shape: mode -> difficulty -> int.
    if (raw is Map && raw[mode] is Map) {
      final value = (raw[mode] as Map)[difficulty];
      return value is num ? value.toInt() : 0;
    }

    // Second shape: mode -> int. Difficulty was not recorded, so attribute it
    // to Easy.
    if (raw is Map && raw[mode] is num) {
      return difficulty == Difficulties.easy ? (raw[mode] as num).toInt() : 0;
    }

    // Original shape: a single int, from before modes existed either.
    if (raw is num) {
      return (mode == GameModes.vsCpu && difficulty == Difficulties.easy)
          ? raw.toInt()
          : 0;
    }

    return 0;
  }

  /// Best streak across all difficulties of [mode] — the headline figure and
  /// the value the Total row shows. It is a MAX, never a sum: a streak cannot
  /// span difficulties.
  static int bestStreakForMode(Map<String, dynamic>? data, String mode) {
    var best = 0;
    for (final d in Difficulties.all) {
      final value = bestStreakFor(data, mode, d);
      if (value > best) best = value;
    }
    return best;
  }

  /// Which difficulty holds [mode]'s best streak, or null when there is none.
  /// Ties resolve in Easy -> Medium -> Hard order.
  static String? bestStreakDifficultyFor(
    Map<String, dynamic>? data,
    String mode,
  ) {
    String? winner;
    var best = 0;
    for (final d in Difficulties.all) {
      final value = bestStreakFor(data, mode, d);
      if (value > best) {
        best = value;
        winner = d;
      }
    }
    return winner;
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

  /// True when `bestStreak` predates the difficulty split: either a bare int
  /// (oldest) or mode -> int (second shape). Both are recognised by the value
  /// under a mode NOT being a map.
  static bool _isLegacyBestStreak(Object? raw) {
    if (raw is num) return true;
    if (raw is Map) {
      return GameModes.all.any((mode) => raw[mode] is num);
    }
    return false;
  }

  /// True when the document still carries any pre-split shape:
  /// six-counter `stats`, or a `bestStreak` without difficulty keys.
  static bool _needsMigration(Map<String, dynamic> data) =>
      _isLegacyStats(data['stats'] as Map<String, dynamic>?) ||
      _isLegacyBestStreak(data['bestStreak']);

  /// Converts any older `bestStreak` shape to mode -> difficulty -> int.
  ///
  /// Pre-difficulty values are attributed to Easy, since the difficulty they
  /// were earned at was never recorded. Where a value already exists under the
  /// new shape the LARGER of the two is kept — streaks are maxima, so adding
  /// them would be meaningless.
  static Map<String, dynamic> migrateLegacyBestStreak(Object? raw) {
    int legacyValueFor(String mode) {
      if (raw is num) return mode == GameModes.vsCpu ? raw.toInt() : 0;
      if (raw is Map && raw[mode] is num) return (raw[mode] as num).toInt();
      return 0;
    }

    int existingValue(String mode, String difficulty) {
      if (raw is Map && raw[mode] is Map) {
        final value = (raw[mode] as Map)[difficulty];
        if (value is num) return value.toInt();
      }
      return 0;
    }

    return <String, dynamic>{
      for (final mode in GameModes.all)
        mode: <String, dynamic>{
          for (final d in Difficulties.all)
            d: d == Difficulties.easy
                ? (existingValue(mode, d) > legacyValueFor(mode)
                      ? existingValue(mode, d)
                      : legacyValueFor(mode))
                : existingValue(mode, d),
        },
    };
  }

  /// The fields that must be rewritten to bring a document up to date.
  /// Only the keys that actually need changing are included.
  static Map<String, dynamic> _migratedFields(Map<String, dynamic> data) {
    final out = <String, dynamic>{};

    final stats = data['stats'] as Map<String, dynamic>?;
    if (_isLegacyStats(stats)) {
      out['stats'] = migrateLegacyStats(stats!);
    }

    final bestStreak = data['bestStreak'];
    if (_isLegacyBestStreak(bestStreak)) {
      out['bestStreak'] = migrateLegacyBestStreak(bestStreak);
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
          'currentStreak': _zeroedCurrentStreak(),
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
  ///
  /// The consecutive-win count is derived from the stored value, not passed in
  /// by the caller — see the `currentStreak` note on the payload below.
  Future<void> recordResult({
    required bool isVsCpu,
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
    final mode = GameModes.fromIsVsCpu(isVsCpu);
    final field = 'stats.$mode.$difficulty.${won ? 'wins' : 'losses'}';

    // Dot-path + increment: atomic server-side, and safe to queue offline.
    final payload = <String, dynamic>{
      field: FieldValue.increment(1),
      // Live streak, maintained SERVER-SIDE rather than from the in-memory
      // counter. The game provider zeroes its streak on every route back to
      // the Main screen, so reading it here would end a run merely because
      // the player opened their profile. Incrementing the stored value
      // instead makes this a true consecutive-win count that survives
      // navigation, app restarts and reinstalls.
      //
      // Written in the SAME update as the win/loss counter, so the two can
      // never disagree and both survive being queued offline.
      'currentStreak.$mode': won ? FieldValue.increment(1) : 0,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await ref.update(payload);
      if (won) {
        await _maybeUpdateBestStreak(ref, mode, difficulty);
      }
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
            'currentStreak': _zeroedCurrentStreak(),
            'stats': _zeroedStats(),
          }, SetOptions(merge: true));
          await ref.update(payload);
          if (won) {
            await _maybeUpdateBestStreak(ref, mode, difficulty);
          }
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

  /// Raises `bestStreak` when the run just extended beats the stored value.
  ///
  /// Firestore has no server-side "max", so this needs a read — hence a
  /// transaction rather than the dot-path increment used for the counters.
  /// The trade-off is that transactions require connectivity: unlike the
  /// win/loss write, this one is NOT queued offline. It is best-effort and
  /// catches up on the next win made while online.
  ///
  /// The streak is read back from the document rather than passed in, so it
  /// always reflects the increment recordResult just committed.
  ///
  /// Never surfaces an error — a game ending must not interrupt the player.
  Future<void> _maybeUpdateBestStreak(
    DocumentReference<Map<String, dynamic>> ref,
    String mode,
    String difficulty,
  ) async {
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data();

        final streak = currentStreakFor(data, mode);
        if (streak <= 0) return;

        // A document still on an older shape must be brought forward in the
        // same write, otherwise the dot-path below would create the nested
        // map alongside the legacy value and strand it.
        if (_isLegacyBestStreak(data?['bestStreak'])) {
          final migrated = migrateLegacyBestStreak(data?['bestStreak']);
          final existing =
              ((migrated[mode] as Map)[difficulty] as num?)?.toInt() ?? 0;
          if (streak > existing) {
            (migrated[mode] as Map)[difficulty] = streak;
          }
          tx.update(ref, <String, dynamic>{
            'bestStreak': migrated,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        final current = bestStreakFor(data, mode, difficulty);
        if (streak <= current) return;
        // Dot path so other modes and difficulties are untouched.
        tx.update(ref, <String, dynamic>{
          'bestStreak.$mode.$difficulty': streak,
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
