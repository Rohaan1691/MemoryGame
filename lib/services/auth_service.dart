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
  ///  * the platform supports it, and
  ///  * real Apple credentials have been filled into auth_config.dart.
  ///
  /// The second check matters on Android: SignInWithApple.isAvailable()
  /// returns TRUE there, because the package supports Apple via a web flow.
  /// That flow needs `webAuthenticationOptions`, which cannot be built from
  /// the TODO placeholders, so without this guard the button renders on
  /// Android and throws the moment it is tapped.
  bool get isAppleAvailable => _appleAvailable && isAppleConfigured;

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
        return const AuthOutcome.failure(
          'Sign-in failed, please try again.',
        );
      }

      // 7.x exposes only idToken on `authentication`; the access token lives on
      // authorizationClient and is not needed for a Firebase credential.
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return const AuthOutcome.failure('Sign-in failed, please try again.');
      }

      await _profileService.upsertOnSignIn(
        user: user,
        provider: AuthProviders.google,
        displayName: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
      );

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
    } on Exception catch (e, st) {
      // Safety net, deliberately last — see the equivalent note in
      // signInWithApple. Ensures no exception reaches the framework unhandled.
      developer.log(
        'Unexpected exception during Google sign-in',
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

  Future<AuthOutcome> signInWithApple() async {
    if (_isBusy) return const AuthOutcome.cancelled();

    // Hard stop before touching the plugin. Without real Apple values the
    // Android/web flow cannot be constructed and the package throws a plain
    // Exception that no typed catch would match.
    if (!isAppleConfigured) {
      developer.log(
        'Apple sign-in attempted while appleServicesId/appleRedirectUri are '
        'still TODO placeholders',
        name: 'AuthService',
      );
      return const AuthOutcome.failure(
        'Sign in with Apple is not available yet.',
      );
    }

    _setBusy(true);
    try {
      // A nonce binds this specific request to the token Apple returns,
      // preventing a captured token from being replayed.
      //
      // Apple receives the SHA-256 HASH and embeds it in the identity token.
      // Firebase receives the RAW string and hashes it itself to compare.
      // Sending these the wrong way round compiles fine and fails at runtime
      // with `invalid-credential`.
      final rawNonce = _generateRawNonce();
      final hashedNonce = _sha256OfString(rawNonce);

      // Required on Android and web, where the flow is browser-based. Null on
      // iOS/macOS, which use the native sheet.
      final webOptions = (kIsWeb || defaultTargetPlatform == TargetPlatform.android)
          ? WebAuthenticationOptions(
              clientId: appleServicesId,
              redirectUri: Uri.parse(appleRedirectUri),
            )
          : null;

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
        webAuthenticationOptions: webOptions,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null) {
        developer.log(
          'Apple sign-in returned a null identityToken',
          name: 'AuthService',
        );
        return const AuthOutcome.failure('Sign-in failed, please try again.');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
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
      final appleName = _composeAppleName(
        appleCredential.givenName,
        appleCredential.familyName,
      );

      await _profileService.upsertOnSignIn(
        user: user,
        provider: AuthProviders.apple,
        displayName: appleName,
        email: appleCredential.email,
      );

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
    } on SignInWithAppleAuthorizationException catch (e, st) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // User dismissed the sheet. Show nothing at all.
        developer.log('Apple sign-in cancelled by user', name: 'AuthService');
        return const AuthOutcome.cancelled();
      }
      developer.log(
        'SignInWithAppleAuthorizationException: code=${e.code} message=${e.message}',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return AuthOutcome.failure(_messageForAppleException(e));
    } on SignInWithAppleException catch (e, st) {
      developer.log(
        'SignInWithAppleException during Apple sign-in',
        name: 'AuthService',
        error: e,
        stackTrace: st,
      );
      return const AuthOutcome.failure('Sign-in failed, please try again.');
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
    } on Exception catch (e, st) {
      // Safety net, deliberately last. The plugin can throw a bare Exception
      // (e.g. "`webAuthenticationOptions` argument must be provided on
      // Android") that matches none of the typed catches above. Without this,
      // such an error escapes to the framework as an unhandled exception and
      // the user sees a dead button with no feedback.
      developer.log(
        'Unexpected exception during Apple sign-in',
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
      final isApple = user.providerData.any(
        (p) => p.providerId == 'apple.com',
      );

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
          developer.log(
            'No stored Apple authorization code; skipping revocation',
            name: 'AuthService',
          );
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

  /// Re-runs the provider flow to refresh the session, then re-authenticates.
  /// Used when `user.delete()` reports `requires-recent-login`.
  Future<AuthOutcome> reauthenticate() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthOutcome.failure('You are not signed in.');
    }

    final isApple = user.providerData.any((p) => p.providerId == 'apple.com');
    return isApple ? signInWithApple() : signInWithGoogle();
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
