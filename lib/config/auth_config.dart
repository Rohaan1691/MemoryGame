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

// TODO — pending Apple Developer account access. Not yet valid.
const appleServicesId = 'TODO_APPLE_PENDING';
const appleRedirectUri = 'TODO_APPLE_PENDING';

/// True once real Apple values have been filled in above. Used to avoid
/// attempting a web-based Apple flow with placeholder credentials.
bool get isAppleConfigured =>
    appleServicesId != 'TODO_APPLE_PENDING' &&
    appleRedirectUri != 'TODO_APPLE_PENDING';

/// Firestore collection holding user profile documents (users/{uid}).
const usersCollection = 'users';

/// Secure-storage key for the Apple authorization code, retained so the token
/// can be revoked at account deletion.
const appleAuthCodeStorageKey = 'apple_authorization_code';
