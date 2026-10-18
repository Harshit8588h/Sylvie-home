# Sylvie — Local Dev Setup (Windows, Zero → Running)

For someone who has never used Flutter. Follow in order. Budget ~2 hours the first time.

## 0. What you need

- Windows 10 or 11 (64-bit)
- 15 GB free on your C: drive
- Stable internet (first install downloads ~5 GB)
- Your Android phone + USB cable
- 2 hours (do it in one sitting; stopping halfway is painful)

## 1. Install Git (if not already)

1. Download: https://git-scm.com/download/win
2. Install with defaults. Done.

Verify in PowerShell:
```
git --version
```

## 2. Install Flutter SDK

1. Download the latest **stable** Flutter zip: https://docs.flutter.dev/get-started/install/windows
2. Create folder `C:\src` (right-click C: → New → Folder → `src`)
3. Extract the zip there. End result: `C:\src\flutter\bin\flutter.bat` should exist.
   - **IMPORTANT**: NOT inside `C:\Program Files` — Windows permission errors later.
4. Add Flutter to PATH:
   - Press Windows key, type `env`, open "Edit the system environment variables"
   - Click **Environment Variables...**
   - Under **User variables**, double-click **Path** → **New** → paste `C:\src\flutter\bin` → OK → OK → OK
5. **Close every PowerShell window** and open a new one. Then:
   ```
   flutter --version
   ```
   Should print `Flutter 3.x.x`. If "not recognized" — PATH wasn't picked up. Reboot and try again.

## 3. Install Android Studio

1. Download: https://developer.android.com/studio
2. Install with defaults (big download, ~1 GB)
3. First launch of Android Studio:
   - It will offer to install the Android SDK — accept
   - "Welcome to Android Studio" screen appears when done
4. **More Actions → SDK Manager**:
   - Tick: **Android 14 (API 34)** → Apply → accept license → wait
   - Click the **SDK Tools** tab, tick:
     - Android SDK Command-line Tools (latest)
     - Android SDK Build-Tools 34
     - Google Play services
   - Apply → wait
5. **More Actions → Plugins**:
   - Search "Flutter" → Install → restart Android Studio when prompted
   - (This also installs the Dart plugin automatically.)

## 4. Accept SDK licenses

In PowerShell:
```
flutter doctor --android-licenses
```
Press `y` to every prompt.

Then:
```
flutter doctor
```
You want green checks for:
- Flutter
- Windows version
- Android toolchain
- Android Studio

Chrome/VS Code warnings can be ignored. Any **red** item — click the URL it prints and fix that one thing before continuing.

## 5. Enable USB debugging on your phone

1. Settings → **About phone** → tap **Build number** 7 times (you'll see "You are now a developer")
2. Settings → **System** → **Developer options** → turn **USB debugging** ON
3. Plug phone into PC with USB cable
4. On the phone, tap **Allow** on the "Allow USB debugging?" prompt (tick "always allow from this computer")

**For Vivo/Oppo/Realme/Xiaomi phones specifically** — also turn ON:
- Developer options → **Install via USB** (ON)
- Developer options → **USB debugging (Security settings)** (ON if present)
- Developer options → **Disable permission monitoring** (ON if present)

Verify in PowerShell:
```
flutter devices
```
Your phone must appear. If it doesn't:
- Try another USB cable (many are charge-only)
- `adb kill-server` then `adb start-server`
- Unplug + replug phone

## 6. Clone this repo and run

In PowerShell:
```
cd Desktop        # or wherever you want the project
git clone https://github.com/Harshit8588h/Sylvie-home.git sylvie
cd sylvie
git checkout claude/fervent-wozniak-5znji7

# Generate the android/ folder (keeps our existing files)
flutter create --project-name sylvie --org com.sylvie --platforms=android .

# Install dependencies
flutter pub get

# Run on your phone
flutter run
```

First build takes 3-5 minutes (Gradle downloads things). After that it's fast.

**Success looks like:** phone shows a screen titled "Sylvie" with text "Sylvie scaffold ready."

**Press `r` in PowerShell** to hot-reload after code changes. **Press `q`** to quit.

## 7. Build a release APK (for family phones, later)

```
flutter build apk --release
```

APK lands at `build\app\outputs\flutter-apk\app-release.apk`. Transfer via WhatsApp/Drive to each family phone and install.

## 8. Firebase

Separate guide: `docs/FIREBASE_SETUP.md`. Do this once after Flutter is working.

---

## Common Windows gotchas

- **"Powershell execution policy" error** when running flutter: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` → `y`
- **Gradle hangs on first build**: patience, it's downloading ~500 MB of Android build tools. Second build is instant.
- **"CMake not found"**: SDK Manager → SDK Tools → tick NDK (side by side) and CMake → Apply
- **Phone not detected**: install the OEM USB driver — for Vivo: https://www.vivo.com/in/support , for Xiaomi: https://en.miui.com/a-234.html , Samsung: Samsung USB Driver on their site. Pixel/OnePlus usually work without.
- **Antivirus (Avast/Norton) killing flutter.bat**: add `C:\src\flutter` to its exclusion list.
