/// Central configuration for authentication providers.
///
/// All auth-related identifiers live here so they are not scattered across
/// the codebase.
///
/// Platform application identifiers differ and must not be confused:
///   Android : com.worldflag.memorygame
///   iOS     : com.worldflags.memory
library;

const firebaseProjectId = 'multimatch-flag-challenge';

/// OAuth 2.0 web client ID (client_type 3) from google-services.json.
/// Passed to GoogleSignIn.initialize() as serverClientId so Firebase receives
/// an ID token minted for the correct audience.
const googleWebClientId =
    '589974754114-ia3updo2p26kqt2opmpvj3dimlp9h3u1.apps.googleusercontent.com';

// SIGN IN WITH APPLE — iOS ONLY
//
// iOS uses the native sheet, driven by:
//   * the "Sign in with Apple" capability on the App ID (Developer portal),
//   * the com.apple.developer.applesignin entitlement in
//     ios/Runner/Runner.entitlements (Xcode-generated — do not hand-edit), and
//   * the Apple provider enabled in the Firebase Console.
//
// It needs no configuration values here.
//
// Apple sign-in is deliberately NOT offered on Android. Android has no native
// Apple support, so it would require a browser round-trip through a Services
// ID, a redirect URI and a SignInWithAppleCallback activity. Firebase's own
// /__/auth/handler cannot terminate that flow (it fails with "missing initial
// state" because the browser has no matching sessionStorage), so it would also
// need a custom redirect endpoint. That was judged not worth the cost; see
// AuthService.isAppleAvailable, which hides the button on non-Apple platforms.

/// Firestore collection holding user profile documents (users/{uid}).
const usersCollection = 'users';

/// Secure-storage key for the Apple authorization code, retained so the token
/// can be revoked at account deletion.
const appleAuthCodeStorageKey = 'apple_authorization_code';

/// Secure-storage key for the display name Apple supplies on the FIRST
/// authorization only.
///
/// Apple never resends it. If the Firestore write fails on that first sign-in
/// the name would otherwise be lost permanently, so it is stashed here and
/// used as a fallback on later sign-ins until it lands.
const appleDisplayNameStorageKey = 'apple_display_name';
