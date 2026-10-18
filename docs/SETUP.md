# Sylvie — Local Dev Setup (Zero → Running)

This guide is for someone who has **never used Flutter before**. Follow in order. Budget ~2 hours the first time.

## 0. What you need

- A laptop/PC (Windows 10/11 or macOS 12+)
- 15 GB free disk
- A stable internet connection (first install downloads ~5 GB)
- An Android phone (your own first — test on it before touching family phones)
- A USB cable (phone → PC)

## 1. Install Flutter

### Windows

1. Download Flutter SDK zip: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\src\flutter` (NOT inside Program Files — permissions bite later)
3. Add `C:\src\flutter\bin` to PATH:
   - Start → "Edit the system environment variables" → Environment Variables → Path → Edit → New → paste `C:\src\flutter\bin` → OK everything
4. Open a NEW PowerShell window and run:
   ```
   flutter --version
   ```
   Should show Flutter 3.x.x. If "not recognized" → PATH is not set right.

### macOS

```bash
# Easiest: Homebrew
brew install --cask flutter

# Verify
flutter --version
```

## 2. Install Android Studio

1. Download: https://developer.android.com/studio
2. Install with defaults
3. First launch → let it install the Android SDK (it will prompt you)
4. In Android Studio: **More Actions → SDK Manager** → confirm these are installed:
   - Android SDK Platform 34 (Android 14)
   - Android SDK Platform-Tools
   - Android SDK Command-line Tools
5. In Android Studio: **More Actions → Plugins** → install **Flutter** plugin (also installs Dart plugin)

## 3. Accept licenses + check setup

```bash
flutter doctor --android-licenses   # press y to each
flutter doctor
```

`flutter doctor` should show green checks for:
- Flutter
- Android toolchain
- Android Studio

If any are red, click the exact URL it prints and fix that one thing.

## 4. Enable Developer Mode on your phone

1. Settings → About phone → tap **Build number** 7 times (you'll see "You are now a developer")
2. Settings → System → Developer options → turn **USB debugging** ON
3. Plug phone into PC with USB cable
4. On the phone, allow the "Allow USB debugging?" prompt (tick "always allow from this computer")

Verify:
```bash
flutter devices
```
Your phone should appear in the list.

## 5. Clone this repo + run

```bash
# Clone
git clone https://github.com/Harshit8588h/Sylvie-home.git sylvie
cd sylvie
git checkout claude/fervent-wozniak-5znji7

# Generate the Android platform folder (does not overwrite our files)
flutter create --project-name sylvie --org com.sylvie --platforms=android .

# Install Dart deps
flutter pub get

# Run on your phone
flutter run
```

If `flutter run` succeeds you'll see the placeholder "Sylvie scaffold ready" screen on your phone. That means your dev setup is working — the rest is just adding code and re-running.

## 6. Build a release APK (for family phones)

Once we have the real app:

```bash
flutter build apk --release
```

APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

Transfer this file to each family phone (WhatsApp, Google Drive, USB) and install. The phone will warn "Unknown source" — allow it from settings for one-time install.

## 7. Firebase (do once, before Firestore wiring commit)

See `docs/FIREBASE_SETUP.md`.

## Troubleshooting

- **`flutter devices` doesn't show my phone**: USB cable is a charging-only cable (common). Try another cable. Also check Developer options → USB debugging is still on.
- **"gradle build failed" on first run**: usually `flutter doctor` has a red item you missed. Fix that, then `flutter clean && flutter pub get && flutter run`.
- **Vivo/Oppo phone shows "Install blocked"**: Settings → Additional settings → Developer options → turn OFF "Verify apps over USB" and "Install via USB" ON.
- **App installs but immediately closes on Vivo/Oppo/Xiaomi**: this is the aggressive-kill problem. Normal, we handle it in-app with the battery-setup wizard. Just open the app once more.
