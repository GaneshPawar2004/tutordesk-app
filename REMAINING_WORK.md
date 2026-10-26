# TutorDesk App — Remaining Work

Flutter Android app for tuition owners (admin) and staff. Part of three repos:
`tutordesk-app` (this), `tutordesk-web` (React), `tutordesk-backend` (Node API).

## Current state

- **Phase 1 is complete: static, interactive UI.** All screens run on local mock data
  (`lib/data/mock_data.dart`) held in memory (`lib/data/app_state.dart`). Data resets on restart.
- Admin and staff previews, role-aware navigation, students, admission, profile, academic
  years and promotion, classes, attendance with locking, parent notifications (simulated),
  fees and payments, staff permissions, exams, marks, results, messages, reports,
  notifications and settings.
- `flutter analyze`: no issues. `flutter test`: 62 tests passing (rules plus every screen
  rendered at 360×640 for admin and staff).
- A debug APK was built but **not yet installed or tested on a real phone**.

See `README.md` for how to run it and a demo walkthrough.

## Setup

```bash
flutter pub get
flutter run          # Android device or emulator
flutter test
flutter analyze
```

Needs Flutter 3.44+ / Dart 3.12. No third-party packages so far.

## Remaining work (suggested order)

1. **Test on real devices.** Install on at least one Android phone, check layouts, the
   keyboard over forms, back navigation and performance with the 128-student seed.
2. **Connect to the backend** (`tutordesk-backend`).
   - Add an HTTP client and replace each `lib/data/repositories/*` mock with an API-backed
     repository. Screens already go through `AppState`, so they should need few changes.
   - Map API errors (401/403/409/400) to UI states. For example, a 409 on attendance save
     should go to the locked session.
   - Add loading and error states where calls are now async (most screens currently assume
     instant data).
   - Configure the API base URL per environment.
3. **Real authentication.** Replace the role picker with a real login (phone OTP or
   password), store the token securely, add logout and session-expiry handling. Keep the
   demo selector behind a dev flag only.
4. **SMS sending.** Replace `SimulatedMessageTransport` with the real transport chosen by
   the backend (Android SIM sender app or gateway). Handle delivery reports. Never claim
   delivery without a report.
5. **Offline behaviour.** At minimum, queue attendance saves when offline and retry. The
   backend must stay the source of truth for locks.
6. **Features shown as "not in demo":** student photo upload, report card PDF / share,
   report export, calling or messaging parents from the profile.
7. **Push notifications** (Firebase Cloud Messaging) for attendance, results and failed messages.
8. **Branding and release:** final app name and icon (currently "TutorDesk"), splash
   screen, the Inter font (currently the system font), release signing, Play Store listing.
9. **Localisation:** Marathi and Hindi UI and message templates.
10. **iOS:** not configured. Only the Android platform was generated.

## Notes and caveats

- Role checks, attendance locks and duplicate-message protection in this app are UI-only.
  Real enforcement lives in the backend.
- Seed data is fictional (Bright Future Classes, Nashik). Ganesh Pawar `STU-0001` is used
  as the reference student in tests (126/150 = 84%).
- In tests, Flutter's font renders glyphs extra wide, so a passing overflow test is strict.
