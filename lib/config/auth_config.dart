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

// SIGN IN WITH APPLE — iOS AND ANDROID
//
// iOS uses the native sheet, driven by:
//   * the "Sign in with Apple" capability on the App ID (Developer portal),
//   * the com.apple.developer.applesignin entitlement in
//     ios/Runner/Runner.entitlements (Xcode-generated — do not hand-edit), and
//   * the Apple provider enabled in the Firebase Console.
//
// Android has no native Apple support, so it runs a browser-based flow that
// additionally needs the two values below plus the SignInWithAppleCallback
// activity registered in android/app/src/main/AndroidManifest.xml with the
// `signinwithapple` scheme. Without that activity the browser cannot hand
// control back to the app.

/// Apple Services ID (a separate identifier from either bundle ID).
const appleServicesId = 'com.worldflags.memory.service';

/// Must match the Return URL configured on the Services ID in the Apple
/// Developer portal. Apple posts the result here and Firebase's auth handler
/// redirects back into the app via the `signinwithapple` scheme.
const appleRedirectUri =
    'https://multimatch-flag-challenge.firebaseapp.com/__/auth/handler';

/// Guards the Apple flow against being offered with placeholder values.
bool get isAppleConfigured =>
    appleServicesId.isNotEmpty &&
    appleRedirectUri.isNotEmpty &&
    !appleServicesId.startsWith('TODO') &&
    !appleRedirectUri.startsWith('TODO');

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
