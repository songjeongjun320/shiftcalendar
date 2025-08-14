# ShiftCalendar (iOS · Android)

An alarm/calendar app optimized for rotating shift schedules (Day · Day · Night · Night · Off · Off). This project was started for my brother and his coworkers. Unlike typical “day-of-week” alarms, ShiftCalendar focuses on cycle-based alarms that move with the shift pattern.

## Why this app?
Conventional alarm apps repeat on fixed weekdays (e.g., every Monday 07:00). Rotating shifts don’t align with fixed weekdays. A common pattern looks like:

- Day → Day → Night → Night → Off → Off → (repeat)

In such patterns, a “Monday” alarm might need to fire on Tuesday next week. Fixed weekday alarms don’t work. ShiftCalendar solves this by planning alarms around the shift cycle instead of calendar weekdays.

## Who is it for?
- People working rotating/shift schedules
- Nurses, manufacturing operators, security/guards, IT/DevOps on shifts, etc.

## Current features
- Pick a time and schedule a local notification
- One-time alarm and daily repeating alarm
- Accurate scheduling using the device’s local timezone
- Notification permission handling on iOS and Android

## Planned features
- Pattern-based scheduler: define a cycle such as D, D, N, N, O, O (or a custom pattern) and auto-shift the alarm according to the day in the cycle
- Restore alarms after device reboot (Android boot broadcast handling)
- Calendar/timeline views that visualize the pattern
- Exceptions (vacation/swap/extra), snooze/missed handling
- Optional data backup/sync

## Platforms & tech stack
- Flutter (Dart)
- Targets iOS and Android
- Key packages: `flutter_local_notifications`, `timezone`, `flutter_native_timezone`

## How alarms work (now)
Inside the app, select a time and choose:
- One-time alarm: if the selected time has passed today, it will schedule for tomorrow
- Daily repeating alarm: schedules the same time every day

The pattern-based scheduler will extend this to shift-driven timing where the alarm automatically moves with the cycle (e.g., D, D, N, N, O, O), not with weekdays.

## Permissions & caveats
- Android 13+: requires notification permission (requested in-app)
- Android exact alarms: some devices/OS versions require an “Exact alarms” or “Alarms & reminders” permission/setting for precise triggers
- iOS: notification permission prompt appears on first use

## Quick start
Prerequisites: Flutter SDK, Android Studio (Android), macOS + Xcode (iOS)

```bash
flutter pub get
flutter run -d android   # Run on Android (e.g., from Windows)
# or
flutter run -d ios       # Run on iOS (from macOS with Xcode)
```

## Project layout (key files)
- `lib/main.dart`: notification init/scheduling UI and logic
- `android/app/src/main/AndroidManifest.xml`: notification/exact alarm permissions
- `pubspec.yaml`: dependencies

## License
This project started for internal use. A formal license may be added or changed later as needed.

---
This app will evolve with feedback from real rotating-shift users (my brother and his coworkers). Suggestions and issues are welcome.
