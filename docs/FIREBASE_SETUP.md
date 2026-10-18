# Firebase Setup (one time)

Sylvie uses Firebase as its backend: phone-number sign-in, Firestore for family data, FCM for push alerts. Everything runs on your personal Google account — no servers to manage.

**Who owns the project:** your personal Gmail (the one you already use for family admin). You stay the sole owner. No one else gets write access to the backend.

**Cost:** ₹0. A 5-person family stays easily inside Firebase's free Spark tier (Firestore 50k reads/day, FCM unlimited, Auth 10k verifications/month).

## Steps

### 1. Create the project

1. Open https://console.firebase.google.com
2. Sign in with your personal Gmail
3. Click **Add project** → name it `sylvie-family` → continue
4. **Disable** Google Analytics for now (we don't need it, keeps data cleaner)
5. Click **Create project** → wait ~30 seconds

### 2. Add the Android app

1. In the project overview, click the **Android** icon
2. Package name: `com.sylvie.sylvie` (EXACTLY this, lowercase)
3. App nickname: `Sylvie Android`
4. SHA-1: skip for now (needed later for release phone auth; we'll add it when we build the signed APK)
5. Click **Register app**
6. Download `google-services.json`
7. Place it at `android/app/google-services.json` in this repo
   - Note: this file is gitignored (contains your project keys). Do not commit it.

### 3. Enable the services we need

In the Firebase console, left sidebar:

- **Authentication** → Get started → Sign-in method → enable **Phone**
  - Add your own phone number to the "Phone numbers for testing" list with a fake OTP (e.g. 123456) so you can test without burning SMS quota
- **Firestore Database** → Create database → start in **production mode** → region: `asia-south1` (Mumbai) — lowest latency for India
- **Cloud Messaging** → nothing to toggle, it's auto-enabled

### 4. Install FlutterFire CLI + wire the app

```bash
# One-time install of the CLI
dart pub global activate flutterfire_cli

# Wire the app to your Firebase project (run from repo root)
flutterfire configure --project=sylvie-family
```

When it asks which platforms, pick only **android**. This generates `lib/firebase_options.dart` (also gitignored).

### 5. Deploy Firestore security rules

```bash
# Install Firebase CLI if needed
npm install -g firebase-tools
firebase login

# From repo root
firebase deploy --only firestore:rules
```

(The rules file lives at `firestore.rules` once we add it in a later commit.)

## That's it

After this, `flutter run` will connect to your Firebase project and phone-OTP auth will work. You never need to touch the Firebase console again day-to-day — only to see data in Firestore if you want to debug.
