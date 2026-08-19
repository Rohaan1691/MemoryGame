import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:memorygame/config/auth_config.dart';
import 'package:memorygame/services/profile_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Provider identifiers stored on the profile document.
class AuthProviders {
  const AuthProviders._();

  static const google = 'google';
  static const apple = 'apple';
}

/// Outcome of an auth operation.
///
/// `cancelled` is deliberately distinct from `failure`: backing out of a
/// sign-in sheet is a normal user action and must not surface any error UI.
enum AuthStatus { success, cancelled, failure }

class AuthOutcome {
  const AuthOutcome._(this.status, {this.message});

  const AuthOutcome.success() : this._(AuthStatus.success);

  const AuthOutcome.cancelled() : this._(AuthStatus.cancelled);

  const AuthOutcome.failure(String message)
    : this._(AuthStatus.failure, message: message);

  final AuthStatus status;

  /// User-facing, actionable copy. Null unless [status] is failure.
  final String? message;

  bool get isSuccess => status == AuthStatus.success;

  bool get isCancelled => status == AuthStatus.cancelled;

  bool get isFailure => status == AuthStatus.failure;
}

/// Authentication for Google and Apple, exposed as a ChangeNotifier to match
/// the app's existing `provider` setup. No second state-management approach is
/// introduced.
class AuthService extends ChangeNotifier {
  AuthService({
    FirebaseAuth? auth,
    ProfileService? profileService,
    FlutterSecureStorage? secureStorage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _profileService = profileService ?? ProfileService(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FirebaseAuth _auth;
  final ProfileService _profileService;
  final FlutterSecureStorage _secureStorage;

  bool _googleInitialised = false;
  bool _appleAvailable = false;
  bool _isBusy = false;

  /// True while an auth operation is in flight. UI uses this to show a loading
  /// state and to reject double-taps.
  bool get isBusy => _isBusy;

  /// Whether Sign in with Apple can be offered.
  ///
  /// Two conditions, both required:
  ///  * the plugin reports support, and
  ///  * we are actually on an Apple platform.
  ///
  /// The second check is not redundant. SignInWithApple.isAvailable() returns
  /// TRUE on Android whenever the package's browser-based flow could run, so
  /// without this guard the button would render on Android — where Apple
  /// sign-in is deliberately not offered.
  bool get isAppleAvailable => _appleAvailable && _isApplePlatform;

  /// True only on iOS/macOS, where the native Sign in with Apple sheet exists.
  static bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => _auth.currentUser != null;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  ProfileService get profileService => _profileService;

  /// One-time setup. Safe to call more than once.
  Future<void> init() async {
    await _ensureGoogleInitialised();
    await _refreshAppleAvailability();
  }

  Future<void> _ensureGoogleInitialised() async {
    if (_googleInitialised) return;
    try {
      // serverClientId is the OAuth *web* client (client_type 3). Passing it
      // makes Google mint an ID token whose audience Firebase accepts.
      await GoogleSignIn.instance.initialize(serverClientId: googleWebClientId);
      _googleInitialised = true;
    } on GoogleSignInException catch (e, st) {
      developer.log(
        'GoogleSignIn.initialize failed: code=${e.code} description=${e.description}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      developer.log(
        'GoogleSignIn.initialize platform error: code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _refreshAppleAvailability() async {
    try {
      final available = await SignInWithApple.isAvailable();
      if (available != _appleAvailable) {
        _appleAvailable = available;
        notifyListeners();
      }
    } on SignInWithAppleException catch (e, st) {
      developer.log(
        'SignInWithApple.isAvailable failed',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      _appleAvailable = false;
    }
  }

  void _setBusy(bool value) {
    if (_isBusy == value) return;
    _isBusy = value;
    notifyListeners();
  }

  // ------------------------------------------------------------------ Google

  Future<AuthOutcome> signInWithGoogle() async {
    if (_isBusy) return const AuthOutcome.cancelled();
    _setBusy(true);
    try {
      await _ensureGoogleInitialised();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        developer.log(
          'GoogleSignIn.authenticate unsupported on this platform',
          name: 'AuthService',
        );
        return const AuthOutcome.failure(
          'Google sign-in is not available on this device.',
        );
      }

      // google_sign_in 7.x: authenticate() throws on cancel rather than
      // returning null, which is the key break from the 6.x API.
      final account = await GoogleSignIn.instance.authenticate();

      final idToken = account.authentication.idToken;
      if (idToken == null) {
        developer.log(
          'Google sign-in returned a null idToken',
          name: 'AuthService',
        );
        return const AuthOutcome.failure('Sign-in failed, please try again.');
      }

      // 7.x exposes only idToken on `authentication`; the access token lives on
      // authorizationClient and is not needed for a Firebase credential.
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return const AuthOutcome.failure('Sign-in failed, please try again.');
      }

      // As with Apple: auth has succeeded, so a profile-write failure must not
      // be reported as a sign-in failure. See the note in signInWithApple.
      try {
        await _profileService.upsertOnSignIn(
          user: user,
          provider: AuthProviders.google,
          displayName: account.displayName,
          email: account.email,
          photoUrl: account.photoUrl,
        );
      } on FirebaseException catch (e, st) {
        developer.log(
          'Profile upsert failed after successful Google auth: '
          'code=${e.code} message=${e.message}',
          name: 'AuthService',
          error: e,
          stackTrace: st,
        );
      }

      return const AuthOutcome.success();
    } on GoogleSignInException catch (e, st) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User backed out. Show nothing.
        developer.log('Google sign-in cancelled by user', name: 'AuthService');
        return const AuthOutcome.cancelled();
      }
      developer.log(
        'GoogleSignInException: code=${e.code} description=${e.description}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return AuthOutcome.failure(_messageForGoogleException(e));
    } on FirebaseAuthException catch (e, st) {
      developer.log(
        'FirebaseAuthException during Google sign-in: code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return AuthOutcome.failure(_messageForAuthException(e, 'Google'));
    } on FirebaseException catch (e, st) {
      developer.log(
        'FirebaseException during Google sign-in: code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure(
        'Signed in, but your profile could not be saved. Please try again.',
      );
    } on PlatformException catch (e, st) {
      developer.log(
        'PlatformException during Google sign-in: code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure('Sign-in failed, please try again.');
    } catch (e, st) {
      // Safety net, deliberately last and untyped — see the equivalent note in
      // signInWithApple. Ensures nothing, Exception or Error, reaches the
      // framework unhandled.
      developer.log(
        'Unexpected throwable during Google sign-in',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure('Sign-in failed, please try again.');
    } finally {
      _setBusy(false);
    }
  }

  // ------------------------------------------------------------------- Apple

  /// Presents the native Apple sheet and builds a Firebase credential from the
  /// result. Returns null only when Apple gives back no identity token.
  ///
  /// Shared by signInWithApple() and reauthenticate() so the nonce handling
  /// exists in exactly one place — duplicating it would risk the two copies
  /// drifting, and a nonce mistake fails only at runtime.
  ///
  /// Throws on cancellation/failure; every caller maps those typed exceptions.
  Future<({OAuthCredential credential, AuthorizationCredentialAppleID raw})?>
  _obtainAppleCredential() async {
    // A nonce binds this specific request to the token Apple returns,
    // preventing a captured token from being replayed.
    //
    // Apple receives the SHA-256 HASH and embeds it in the identity token.
    // Firebase receives the RAW string and hashes it itself to compare.
    // Sending these the wrong way round compiles fine and fails at runtime
    // with `invalid-credential`.
    final rawNonce = _generateRawNonce();
    final hashedNonce = _sha256OfString(rawNonce);

    // No webAuthenticationOptions: that parameter exists only for the
    // browser-based Android/web flow, which this app does not offer. On iOS
    // this uses the native sheet, which needs no Services ID or redirect URI.
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final identityToken = appleCredential.identityToken;
    if (identityToken == null) {
      developer.log(
        'Apple sign-in returned a null identityToken',
        name: 'AuthService',
      );
      return null;
    }

    final oauthCredential = OAuthProvider(
      'apple.com',
    ).credential(idToken: identityToken, rawNonce: rawNonce);
    return (credential: oauthCredential, raw: appleCredential);
  }

  /// Runs the Google sheet and builds a Firebase credential.
  /// Returns null when Google gives back no ID token.
  Future<AuthCredential?> _obtainGoogleCredential() async {
    await _ensureGoogleInitialised();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      developer.log(
        'GoogleSignIn.authenticate unsupported on this platform',
        name: 'AuthService',
      );
      return null;
    }

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      developer.log(
        'Google sign-in returned a null idToken',
        name: 'AuthService',
      );
      return null;
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  Future<AuthOutcome> signInWithApple() async {
    if (_isBusy) return const AuthOutcome.cancelled();

    // Hard stop before touching the plugin. On a non-Apple platform the
    // package would take its browser-based path, which this app does not
    // configure, and throw a plain Exception that no typed catch would match.
    // Reachable via reauthenticate(), which does not go through the login
    // screen's visibility check.
    if (!_isApplePlatform) {
      developer.log(
        'Apple sign-in attempted on a non-Apple platform; it is iOS-only here',
        name: 'AuthService',
      );
      return const AuthOutcome.failure(
        'Sign in with Apple is not available on this device.',
      );
    }

    _setBusy(true);
    try {
      final obtained = await _obtainAppleCredential();
      if (obtained == null) {
        return const AuthOutcome.failure('Sign-in failed, please try again.');
      }
      final appleCredential = obtained.raw;

      final userCredential = await _auth.signInWithCredential(
        obtained.credential,
      );
      final user = userCredential.user;
      if (user == null) {
        return const AuthOutcome.failure('Sign-in failed, please try again.');
      }

      // Retained so the token can be revoked at account deletion. Apple
      // requires revocation, not just deletion of the Firebase user.
      await _storeAppleAuthorizationCode(appleCredential.authorizationCode);

      // Apple sends givenName / familyName ONLY on the very first
      // authorization for a given Apple ID, and null on every subsequent
      // sign-in. Capture it now; the upsert guards against a later null
      // overwriting what we stored.
      var appleName = _composeAppleName(
        appleCredential.givenName,
        appleCredential.familyName,
      );

      if (appleName != null) {
        // Stash immediately. Apple never resends this, so if the Firestore
        // write below fails the name would otherwise be gone for good.
        await _storeAppleDisplayName(appleName);
      } else {
        // Recover a name captured on an earlier attempt whose write failed.
        appleName = await _readStoredAppleDisplayName();
      }

      // A profile-write failure must NOT fail the sign-in: authentication has
      // already succeeded, so returning a failure here would leave the UI
      // showing an error while the user is actually signed in. Firestore
      // queues writes offline and replays them, and recordResult recreates a
      // missing document, so this is recoverable on its own.
      try {
        await _profileService.upsertOnSignIn(
          user: user,
          provider: AuthProviders.apple,
          displayName: appleName,
          email: appleCredential.email,
        );
      } on FirebaseException catch (e, st) {
        developer.log(
          'Profile upsert failed after successful Apple auth: '
          'code=${e.code} message=${e.message}',
          name: 'AuthService',
          error: e,
          stackTrace: st,
        );
      }

      // Mirror onto the FirebaseAuth profile too, but only on first capture.
      if (appleName != null &&
          (user.displayName == null || user.displayName!.trim().isEmpty)) {
        try {
          await user.updateDisplayName(appleName);
        } on FirebaseAuthException catch (e, st) {
          developer.log(
            'updateDisplayName after Apple sign-in failed: code=${e.code}',
            name: 'AuthService',
            error: e,
            stackTrace: st,
          );
        }
      }

      return const AuthOutcome.success();
    } on SignInWithAppleException catch (e, st) {
      // Single clause: every sign_in_with_apple error type implements this,
      // including UnknownSignInWithAppleException (which also extends
      // PlatformException, so it must be caught before the PlatformException
      // clause below). Branching happens in the mapper.
      return _outcomeForAppleException(e, st, phase: 'sign-in');
    } on FirebaseAuthException catch (e, st) {
      developer.log(
        'FirebaseAuthException during Apple sign-in: code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return AuthOutcome.failure(_messageForAuthException(e, 'Apple'));
    } on FirebaseException catch (e, st) {
      developer.log(
        'FirebaseException during Apple sign-in: code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure(
        'Signed in, but your profile could not be saved. Please try again.',
      );
    } on PlatformException catch (e, st) {
      developer.log(
        'PlatformException during Apple sign-in: code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure('Sign-in failed, please try again.');
    } catch (e, st) {
      // Safety net, deliberately last and deliberately untyped. Plugins can
      // throw a bare Exception (e.g. "`webAuthenticationOptions` argument must
      // be provided on Android") or an Error subclass, neither of which the
      // typed catches above match. Without this, it escapes to the framework
      // as an unhandled error and the user sees a dead button with no
      // feedback. Full detail is logged so nothing is silently swallowed.
      developer.log(
        'Unexpected throwable during Apple sign-in',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure('Sign-in failed, please try again.');
    } finally {
      _setBusy(false);
    }
  }

  // ----------------------------------------------------------------- sign out

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } on GoogleSignInException catch (e, st) {
      // Non-fatal: we still sign out of Firebase below.
      developer.log(
        'GoogleSignIn.signOut failed: code=${e.code}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      developer.log(
        'GoogleSignIn.signOut platform error: code=${e.code}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
    }

    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e, st) {
      developer.log(
        'FirebaseAuth.signOut failed: code=${e.code}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------- display name

  /// Updates the display name in both FirebaseAuth and Firestore.
  /// Firestore is the source of truth for display; the Auth profile is kept in
  /// step so other surfaces see the same value.
  Future<AuthOutcome> updateDisplayName(String newName) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthOutcome.failure('You are not signed in.');
    }
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      return const AuthOutcome.failure('Please enter a name.');
    }

    try {
      await user.updateDisplayName(trimmed);
      await _profileService.updateDisplayName(
        uid: user.uid,
        displayName: trimmed,
      );
      notifyListeners();
      return const AuthOutcome.success();
    } on FirebaseAuthException catch (e, st) {
      developer.log(
        'updateDisplayName auth failure: code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return AuthOutcome.failure(
        e.code == 'network-request-failed'
            ? 'No internet connection. Your name was not saved.'
            : 'Your name could not be saved. Please try again.',
      );
    } on FirebaseException catch (e, st) {
      developer.log(
        'updateDisplayName firestore failure: code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure(
        'Your name could not be saved. Please try again.',
      );
    }
  }

  // ------------------------------------------------------- account deletion

  /// Deletes the account permanently.
  ///
  /// Order matters. Apple token revocation and the Firestore delete both run
  /// BEFORE `user.delete()`; if either fails we stop and leave the account
  /// intact rather than orphaning data behind a deleted auth user.
  ///
  /// `requires-recent-login` is an expected path, not an error: the caller is
  /// asked to re-authenticate and then calls this again with
  /// [alreadyReauthenticated] set.
  Future<DeleteAccountOutcome> deleteAccount() async {
    if (_isBusy) return DeleteAccountOutcome.failure('Please wait.');
    final user = _auth.currentUser;
    if (user == null) {
      return DeleteAccountOutcome.failure('You are not signed in.');
    }

    _setBusy(true);
    try {
      final isApple = user.providerData.any((p) => p.providerId == 'apple.com');

      // 1. Revoke the Apple token first. Required by Apple; deleting the
      //    Firebase user alone is not sufficient.
      if (isApple) {
        final authCode = await _readAppleAuthorizationCode();
        if (authCode != null && authCode.isNotEmpty) {
          try {
            await _auth.revokeTokenWithAuthorizationCode(authCode);
          } on FirebaseAuthException catch (e, st) {
            developer.log(
              'revokeTokenWithAuthorizationCode failed: code=${e.code} message=${e.message}',
              name: 'AuthService',
              error: e,
              stackTrace: st,
            );
            return DeleteAccountOutcome.failure(
              'Your Apple sign-in could not be revoked, so your account was '
              'not deleted. Please try again.',
            );
          }
        } else {
          // No code stored (secure-storage write failed, or the account was
          // created by a build predating this storage). Apple REQUIRES token
          // revocation, so deleting without it would leave the app authorised
          // in the user's Apple ID settings and orphan the grant.
          //
          // Ask for re-authentication instead of skipping: reauthenticate()
          // stores a fresh authorization code, after which the retry can
          // revoke properly.
          developer.log(
            'No stored Apple authorization code; requesting re-auth to obtain '
            'one before deletion',
            name: 'AuthService',
          );
          return DeleteAccountOutcome.requiresReauthentication();
        }
      }

      // 2. Delete the profile document while still authenticated — the
      //    security rules require an authenticated owner.
      try {
        await _profileService.deleteProfile(user.uid);
      } on FirebaseException catch (e, st) {
        developer.log(
          'deleteProfile failed: code=${e.code} message=${e.message}',
          name: 'AuthService',
          error: e,
          stackTrace: st,
        );
        return DeleteAccountOutcome.failure(
          'Your scores could not be deleted, so your account was not removed. '
          'Please try again.',
        );
      }

      // 3. Finally delete the auth user.
      try {
        await user.delete();
      } on FirebaseAuthException catch (e, st) {
        if (e.code == 'requires-recent-login') {
          developer.log(
            'user.delete requires recent login; re-authentication needed',
            name: 'AuthService',
          );
          return DeleteAccountOutcome.requiresReauthentication();
        }
        developer.log(
          'user.delete failed: code=${e.code} message=${e.message}',
          name: 'AuthService',
          error: e,
          stackTrace: st,
        );
        return DeleteAccountOutcome.failure(
          e.code == 'network-request-failed'
              ? 'No internet connection. Please try again.'
              : 'Your account could not be deleted. Please try again.',
        );
      }

      await _clearAppleAuthorizationCode();
      await _clearStoredAppleDisplayName();
      try {
        await GoogleSignIn.instance.signOut();
      } on GoogleSignInException catch (e, st) {
        developer.log(
          'GoogleSignIn.signOut after delete failed: code=${e.code}',
          name: 'AuthService',
          error: e,
          stackTrace: st,
        );
      }

      notifyListeners();
      return DeleteAccountOutcome.success();
    } finally {
      _setBusy(false);
    }
  }

  /// Refreshes the session for the CURRENT user.
  /// Used when `user.delete()` reports `requires-recent-login`.
  ///
  /// This deliberately uses `reauthenticateWithCredential`, not
  /// `signInWithCredential`. The difference is critical during account
  /// deletion: `signInWithCredential` would happily switch the session to a
  /// different account if the user picked another Apple ID or Google account
  /// at the sheet, and the deletion that follows would then destroy THAT
  /// account instead of the intended one. `reauthenticateWithCredential`
  /// rejects a credential belonging to anyone else with `user-mismatch`.
  Future<AuthOutcome> reauthenticate() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthOutcome.failure('You are not signed in.');
    }
    if (_isBusy) return const AuthOutcome.cancelled();

    final uidBefore = user.uid;
    final isApple = user.providerData.any((p) => p.providerId == 'apple.com');

    if (isApple && !_isApplePlatform) {
      developer.log(
        'Apple re-authentication attempted on a non-Apple platform',
        name: 'AuthService',
      );
      return const AuthOutcome.failure(
        'Sign in with Apple is not available on this device.',
      );
    }

    _setBusy(true);
    try {
      final AuthCredential credential;

      if (isApple) {
        final obtained = await _obtainAppleCredential();
        if (obtained == null) {
          return const AuthOutcome.failure(
            'Re-authentication failed, please try again.',
          );
        }
        credential = obtained.credential;
        // Refresh the stored authorization code while we have a fresh one.
        // Deletion needs it to revoke, and this is the natural moment to
        // repair a missing or stale value.
        await _storeAppleAuthorizationCode(obtained.raw.authorizationCode);
      } else {
        final googleCredential = await _obtainGoogleCredential();
        if (googleCredential == null) {
          return const AuthOutcome.failure(
            'Re-authentication failed, please try again.',
          );
        }
        credential = googleCredential;
      }

      await user.reauthenticateWithCredential(credential);

      // Belt and braces: reauthenticateWithCredential should already have
      // thrown user-mismatch, but never proceed to a delete if the signed-in
      // identity changed for any reason.
      if (_auth.currentUser?.uid != uidBefore) {
        developer.log(
          'Re-authentication changed the active user; aborting',
          name: 'AuthService',
        );
        return const AuthOutcome.failure(
          'That is a different account. Please sign in again with the account '
          'you want to delete.',
        );
      }

      return const AuthOutcome.success();
    } on SignInWithAppleException catch (e, st) {
      // Same single-clause mapping as sign-in; see _outcomeForAppleException.
      return _outcomeForAppleException(e, st, phase: 're-authentication');
    } on GoogleSignInException catch (e, st) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        developer.log(
          'Google re-authentication cancelled by user',
          name: 'AuthService',
        );
        return const AuthOutcome.cancelled();
      }
      developer.log(
        'GoogleSignInException during re-auth: code=${e.code}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return AuthOutcome.failure(_messageForGoogleException(e));
    } on FirebaseAuthException catch (e, st) {
      developer.log(
        're-authentication failed: code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return AuthOutcome.failure(
        _messageForAuthException(e, isApple ? 'Apple' : 'Google'),
      );
    } on PlatformException catch (e, st) {
      developer.log(
        'PlatformException during re-auth: code=${e.code}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure(
        'Re-authentication failed, please try again.',
      );
    } catch (e, st) {
      // Last resort. Catches Error subclasses too (a plugin TypeError, for
      // example), which `on Exception` would let escape into the framework as
      // an unhandled error mid-deletion.
      developer.log(
        'Unexpected throwable during re-auth',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure(
        'Re-authentication failed, please try again.',
      );
    } finally {
      _setBusy(false);
    }
  }

  // -------------------------------------------------------- secure storage

  Future<void> _storeAppleAuthorizationCode(String code) async {
    try {
      await _secureStorage.write(key: appleAuthCodeStorageKey, value: code);
    } on PlatformException catch (e, st) {
      developer.log(
        'Failed to store Apple authorization code: code=${e.code}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<String?> _readAppleAuthorizationCode() async {
    try {
      return await _secureStorage.read(key: appleAuthCodeStorageKey);
    } on PlatformException catch (e, st) {
      developer.log(
        'Failed to read Apple authorization code: code=${e.code}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Persists the name Apple supplies on the first authorization only, so a
  /// failed Firestore write cannot lose it permanently.
  Future<void> _storeAppleDisplayName(String name) async {
    try {
      await _secureStorage.write(key: appleDisplayNameStorageKey, value: name);
    } on PlatformException catch (e, st) {
      developer.log(
        'Failed to store Apple display name: code=${e.code}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<String?> _readStoredAppleDisplayName() async {
    try {
      final value = await _secureStorage.read(key: appleDisplayNameStorageKey);
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } on PlatformException catch (e, st) {
      developer.log(
        'Failed to read Apple display name: code=${e.code}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> _clearStoredAppleDisplayName() async {
    try {
      await _secureStorage.delete(key: appleDisplayNameStorageKey);
    } on PlatformException catch (e, st) {
      developer.log(
        'Failed to clear Apple display name: code=${e.code}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _clearAppleAuthorizationCode() async {
    try {
      await _secureStorage.delete(key: appleAuthCodeStorageKey);
    } on PlatformException catch (e, st) {
      developer.log(
        'Failed to clear Apple authorization code: code=${e.code}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ---------------------------------------------------------------- helpers

  /// Cryptographically secure random string used as the raw nonce.
  static String _generateRawNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static String? _composeAppleName(String? given, String? family) {
    final parts = [
      given?.trim(),
      family?.trim(),
    ].where((p) => p != null && p.isNotEmpty).cast<String>().toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  static String _messageForAuthException(
    FirebaseAuthException e,
    String attemptedProvider,
  ) {
    switch (e.code) {
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'account-exists-with-different-credential':
        final other = attemptedProvider == 'Google' ? 'Apple' : 'Google';
        return 'This email is already registered with $other. '
            'Please sign in with $other instead.';
      case 'invalid-credential':
        // Almost always a configuration problem rather than a user problem.
        return 'Sign-in failed, please try again.';
      case 'user-mismatch':
        // Raised by reauthenticateWithCredential when the chosen account is
        // not the signed-in one. Critical during deletion.
        return 'That is a different account. Please choose the account you '
            'are signed in with.';
      case 'user-not-found':
        return 'This account no longer exists.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      default:
        return 'Sign-in failed, please try again.';
    }
  }

  static String _messageForGoogleException(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.interrupted:
        return 'Sign-in was interrupted. Please try again.';
      default:
        return 'Sign-in failed, please try again.';
    }
  }

  /// Maps ANY sign_in_with_apple exception to an outcome.
  ///
  /// One clause covers every subtype because they all implement
  /// SignInWithAppleException — including UnknownSignInWithAppleException,
  /// which also extends PlatformException and would otherwise be swallowed by
  /// a `on PlatformException` clause placed earlier.
  ///
  AuthOutcome _outcomeForAppleException(
    SignInWithAppleException e,
    StackTrace st, {
    required String phase,
  }) {
    if (e is SignInWithAppleAuthorizationException) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // User dismissed the native sheet. Show nothing at all.
        developer.log('Apple $phase cancelled by user', name: 'AuthService');
        return const AuthOutcome.cancelled();
      }
      developer.log(
        'SignInWithAppleAuthorizationException during $phase: '
        'code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return AuthOutcome.failure(_messageForAppleException(e));
    }

    if (e is SignInWithAppleNotSupportedException) {
      developer.log(
        'SignInWithAppleNotSupportedException during $phase: ${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure(
        'Sign in with Apple is not available on this device.',
      );
    }

    if (e is SignInWithAppleCredentialsException) {
      // Apple returned a response we could not read.
      developer.log(
        'SignInWithAppleCredentialsException during $phase: ${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure('Sign-in failed, please try again.');
    }

    if (e is UnknownSignInWithAppleException) {
      // Any plugin error the platform interface could not map to a typed
      // exception. Kept as a catch-all so nothing reaches the user as a dead
      // button; the code is logged for diagnosis.
      developer.log(
        'UnknownSignInWithAppleException during $phase: '
        'code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure('Sign-in failed, please try again.');
    }

    developer.log(
      'SignInWithAppleException during $phase',
      name: 'AuthService',
      error: e,
      stackTrace: st,
    );
    return const AuthOutcome.failure('Sign-in failed, please try again.');
  }

  static String _messageForAppleException(
    SignInWithAppleAuthorizationException e,
  ) {
    switch (e.code) {
      case AuthorizationErrorCode.notHandled:
      case AuthorizationErrorCode.failed:
        return 'Sign-in failed, please try again.';
      case AuthorizationErrorCode.notInteractive:
        return 'Sign in with Apple is unavailable right now.';
      case AuthorizationErrorCode.invalidResponse:
        return 'Sign-in failed, please try again.';
      default:
        return 'Sign-in failed, please try again.';
    }
  }
}

/// Result of the multi-step account deletion flow.
class DeleteAccountOutcome {
  const DeleteAccountOutcome._(this.status, {this.message});

  factory DeleteAccountOutcome.success() =>
      const DeleteAccountOutcome._(DeleteAccountStatus.success);

  factory DeleteAccountOutcome.requiresReauthentication() =>
      const DeleteAccountOutcome._(DeleteAccountStatus.requiresReauth);

  factory DeleteAccountOutcome.failure(String message) =>
      DeleteAccountOutcome._(DeleteAccountStatus.failure, message: message);

  final DeleteAccountStatus status;
  final String? message;

  bool get isSuccess => status == DeleteAccountStatus.success;

  bool get requiresReauth => status == DeleteAccountStatus.requiresReauth;

  bool get isFailure => status == DeleteAccountStatus.failure;
}

enum DeleteAccountStatus { success, requiresReauth, failure }
