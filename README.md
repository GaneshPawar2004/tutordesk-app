# TutorDesk — Tuition Management App (Phase 1: static UI)

Flutter Android app for tuition owners and staff. This phase is an **interactive UI
prototype**: every screen runs on local mock data and in-memory state. There is no
backend, database, login API, SMS provider or payment gateway.

## Run it

```bash
cd app
flutter pub get
flutter run            # on an Android device or emulator
flutter test           # unit + widget smoke tests
flutter analyze
```

Requires Flutter 3.44+ (Dart 3.12). No third-party packages are used.

## Important limitations (read before demoing)

- **Data resets on restart.** Everything you add (students, payments, attendance,
  marks, messages) lives in memory for the current session only.
- **Role switching is not security.** Admin/Staff previews only change what the UI
  shows. Real access control and tenant isolation must be enforced by the backend.
- **Attendance locks and duplicate-message protection are client-side only.** They
  demonstrate the intended behaviour; the backend must enforce real locking and
  idempotency.
- **No real messages are sent.** Sending is simulated on the device with timers
  (some numbers fail on the first attempt so retries can be shown). SMS allowance,
  device name and sync time are labelled mock values — an ordinary SIM balance
  cannot be read by a server, and "Delivered" only appears when a device/gateway
  would report it.
- Photo upload, PDF/print, sharing and report export are shown as UI only and are
  labelled as unavailable in the demo.

## Demo walkthrough

1. **Welcome** → *Admin preview* (Rahul Sharma) or *Staff preview* (pick a staff
   member; each has different permissions).
2. **Home**: cream summary (128 active students, 6 classes, 4 of 6 classes marked),
   metric cards, quick actions, activity feed, upcoming exams/events, academic-year
   selector, notifications.
3. **Students**: search/filter, open *Ganesh Pawar (STU-0001)* → Overview,
   Attendance calendar, Exams & Marks, Academic History (Class 4 → Class 5), and
   the admin-only Fees tab. Add a student from the + button (live fee calculation).
4. **Attendance**: start *Class 7* or *Class 10*, use *All present*, save & lock.
   Use the ⋮ menu → *Demo: colleague saves first* to see the duplicate-submission
   lock. Then *Notify parents* → preview → send → watch statuses; *Retry failed*
   retries only failures.
5. **More → Exams & marks**: *Sunday Weekly Test* (Class 5, published) → results,
   report card (126/150 = 84%), send results to parents. *Unit Test 2* (Class 8)
   has partly entered draft marks to finish and publish.
6. **More → Fees** (admin): totals, overdue list, record a partial payment, send
   fee reminders (once per day).
7. **More → Staff**: toggle *Send SMS notifications* off for Sneha, then
   *Preview as Sneha* — Send actions disappear.
8. **More → Academic years → Promote students**: Class 5 (2026–27) → Class 6
   (2027–28). IDs stay the same; last year's fee and dues stay on last year.

## Structure

```text
lib/
├── main.dart, app.dart          # entry, theme, role gate
├── core/
│   ├── theme/                   # colours, type scale, Material 3 theme
│   ├── navigation/              # AppShell (bottom nav), push helpers
│   └── utils/                   # ₹/date/phone formatting, grading
├── data/
│   ├── app_state.dart           # session, permissions, cross-domain actions
│   ├── app_scope.dart           # InheritedNotifier access to AppState
│   ├── mock_data.dart           # deterministic seed (fictional data)
│   ├── message_templates.dart   # parent message text (separate from transport)
│   └── repositories/            # in-memory repositories + simulated transport
├── shared/
│   ├── models/                  # Student, Enrollment, FeePlan, Payment, Exam, …
│   └── widgets/                 # design-system components
└── features/                    # one folder per module (screens)
```

Swapping in a real backend means replacing the repositories in
`data/repositories/` and the `MessageTransport` implementation; screens talk to
`AppState`, not to mock data directly.

### Data model notes

- A **Student** is a permanent identity (STU-0001). Each academic year adds an
  **Enrollment**; promotion never copies the student.
- A **FeePlan** belongs to one enrollment. **Payments** are append-only; balances
  are always derived.
- Exam totals and percentages are computed from subject marks. Absent is stored as
  absent, never as zero.
- A **MessageBatch** has a `sourceKey` (attendance session, published exam
  revision, announcement draft, daily fee reminder) that prevents duplicates.
