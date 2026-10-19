// GENERATED FILE — placeholder.
//
// Running `flutterfire configure --project=sylvie-family` (see
// docs/FIREBASE_SETUP.md) overwrites this file with your project's real
// values. The app checks the sentinel below at startup and refuses to
// initialize Firebase while the placeholder is in place, so you'll see
// a clear "Firebase not configured" screen until you run flutterfire.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

const kFirebasePlaceholderSentinel = 'REPLACE_ME_RUN_FLUTTERFIRE_CONFIGURE';

class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: kFirebasePlaceholderSentinel,
    appId: kFirebasePlaceholderSentinel,
    messagingSenderId: kFirebasePlaceholderSentinel,
    projectId: kFirebasePlaceholderSentinel,
    storageBucket: kFirebasePlaceholderSentinel,
  );

  static FirebaseOptions get currentPlatform => android;

  static bool get isConfigured =>
      android.apiKey != kFirebasePlaceholderSentinel;
}
