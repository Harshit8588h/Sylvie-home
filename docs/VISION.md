# Sylvie — Vision

## Problem

Primary driver: a grandmother with memory loss (under treatment at AIIMS) who sometimes wanders out of the house. Her phone is always with her. The family needs to know, within a minute, if she has left home — and where she is.

Secondary: everyone in the house (self, mother, father, sister, grandmother) should be able to see where the others are. Peace of mind, nothing more.

## v0.1 — Family Safe (scope lock)

- One Android app for all 5 family members
- Phone number sign-in (Firebase Auth)
- Live map with everyone's current location, battery, last-seen
- Per-member safe zones (home, hospital, etc.)
- Instant push alert when a member crosses an exit zone
- Phone-offline watchdog: no ping for 15 min = alert
- Low-battery alert (anyone under 20%)
- "Call" and "message" shortcut per family member
- Per-OEM battery setup wizard (Vivo first — grandma's phone)

Explicitly NOT in v0.1: iOS, voice, cameras, home-device control, Hindi TTS, AI.

## v0.2 — Hardening

- Multiple safe zones per member (home + hospital + relatives)
- 24h location history (trail on map)
- "Trip mode" — temporarily suppress alerts for a known outing
- SOS button on each phone (big, one-tap, calls everyone)
- Trusted contacts outside the family who can also receive alerts
- Backup server-side watchdog (Cloud Function) for phone-offline detection

## v1.0 — Sylvie Home integration

Once the home AI brain exists (Mac Mini M4 + Qwen local LLM + device connectors), the family app becomes one of its sensors:
- Sylvie knows who is home, who is away, how far
- Voice: "Sylvie, dadi kahaan hain?" → spoken answer
- Automation: when everyone is out, arm cameras + lock mode
- Health signal: unusual stationary periods detected and flagged

## Non-goals

- Not a medical device. Not a fall detector. Not a diagnostic tool.
- Not a replacement for family vigilance. Software is one layer, not the plan.
- Not a product. This is a personal family tool. No app store, no users beyond the household.
