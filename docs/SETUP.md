# Sylvie — Local Dev Setup

This repo contains the Flutter source only. The platform-specific `android/` folder is generated locally (it is large and not worth committing).

## Prerequisites

- Flutter SDK >= 3.22 (`flutter --version`)
- Android Studio with Android SDK + an emulator OR a physical Android device with USB debugging
- A Firebase project (we will create one — see "Firebase setup" below)

## First-time setup

```bash
# 1. Clone
git clone <this-repo> sylvie
cd sylvie

# 2. Generate the Android platform folder (does not overwrite our lib/ or pubspec.yaml
#    because we pass --platforms=android and the files already exist).
flutter create --project-name sylvie --org com.sylvie --platforms=android .

# 3. Install Dart deps
flutter pub get

# 4. Run on a connected device/emulator
flutter run
```

If `flutter create` complains about existing files, that is fine — it only writes the missing platform scaffolding.

## Firebase setup

TODO (filled in once we decide which Google account owns the project).

1. Create a Firebase project at console.firebase.google.com
2. Add an Android app with package `com.sylvie.sylvie`
3. Download `google-services.json` → place in `android/app/`
4. Run `flutterfire configure` to generate `lib/firebase_options.dart`

(Note: `google-services.json` and `firebase_options.dart` are gitignored.)

## Running on a real phone

```bash
# USB debugging on the phone, then:
flutter devices        # confirm phone shows up
flutter run            # debug build
flutter build apk --release    # release APK for distribution to family
```

The release APK will be at `build/app/outputs/flutter-apk/app-release.apk`. Side-load this to family phones.
