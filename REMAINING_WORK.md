# TutorDesk App — Status & Remaining Work

Flutter Android app for tuition admins and staff. Part of three repos:
`tutordesk-app` (this), `tutordesk-web` (React), `tutordesk-backend` (Node API).

## Setup

```bash
flutter pub get
flutter run            # Android device/emulator
flutter build apk --debug
```

The backend must be running (see tutordesk-backend). On first launch the sign-in
screen has a **Server address** field (default `http://192.168.0.117:4000` — the PC's
Wi‑Fi address); the phone must be on the same Wi‑Fi. If the phone cannot reach the PC,
run `adb reverse tcp:4000 tcp:4000` and use `http://127.0.0.1:4000`.

## What works

- **Connected to the real backend.** Register a tuition, log in with phone/email +
  password, or join as staff with an invite code. The login is remembered on the phone.
- On sign-in the app downloads everything the user may see (`GET /api/sync`); every
  change is sent to the server and the app re-syncs. Message statuses refresh every
  2 seconds while sending.
- All screens from Phase 1 now save to the server: classes, academic years, admission,
  student edit, attendance (+ admin correction), notify parents, fees & payments, exams,
  marks, publish, send results, announcements, fee reminders, staff & permissions
  (invite code shown to the admin), promotion, notifications, tuition/profile settings.
- First-run "Get started" checklist for a new, empty tuition.
- Offline sample-data mode is kept only for the automated widget tests
  (`AppState()`); the real app uses `AppState.remote()`.

## Not verified yet

The connected version compiles (`flutter analyze`: no issues) and was installed on the
POCO, but has **not been tested end to end yet**. The widget/unit tests were updated to
compile but were not re-run.

## Remaining work

1. **End-to-end testing** on a real phone, then re-run `flutter test` and fix anything found.
2. SIM sender (Messages → SMS settings → "Send from this phone", `lib/data/remote/sms_sender.dart`
   + `MainActivity.kt`) only runs while the app is open; a foreground service for background
   sending is not built. Play Store restricts SEND_SMS apps.
3. Offline behaviour (queue attendance when there is no network).
4. Forgot/change password screens; logout of other devices.
5. Photo upload, report-card PDF/share, report export (shown as "not available").
6. Push notifications (FCM).
7. Release: app icon, splash, Inter font, release signing, Play Store listing; HTTPS
   server address once the backend is deployed (then remove `usesCleartextTraffic`).
8. Marathi/Hindi localisation. iOS is not configured.
