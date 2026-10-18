# Sylvie

A private, lightweight family safety app for Android. Built so every family member can see each other on a map, know who is home, and get instant alerts when someone leaves a safe zone (primary use case: supporting a family member with memory loss).

Sylvie is also the brain that will later connect to the home itself — lights, cameras, TV, voice. The app is step one.

## Family

- Admin + members (5 slots to start): self, mother, father, sister, grandmother
- Everyone sees everyone's live location, battery, and last-seen time
- Per-person safe zones with exit/enter alerts
- Phone-offline watchdog (if a phone stops reporting for 15 min, family is alerted)

## Design goals

- **Battery-light**: event-based geofencing, not polling. Target < 5% battery/day on the sender's phone.
- **APK < 15 MB**, RAM footprint < 80 MB background.
- **OEM-aware**: Vivo / Oppo / Xiaomi aggressive-kill handled with per-OEM setup guides inside the app.
- **Private**: data lives in the family's own Firebase project, nowhere else. No ads, no analytics.
- **Minimum Android**: 8.0 (API 26).

## Status

Pre-alpha. Scaffold only. See `docs/VISION.md` for the roadmap and `docs/SETUP.md` for local dev setup.
