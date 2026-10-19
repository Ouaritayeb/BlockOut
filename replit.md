# BlockOut

A Flutter Android app that lets people select installed apps and block them during a timed focus session.

## Run & Operate

- `cd artifacts/blockout && flutter pub get && flutter run` — run BlockOut on an Android device or emulator with Flutter installed
- `cd artifacts/blockout && flutter analyze` — analyze the Flutter app
- `pnpm run typecheck` — typecheck the workspace's TypeScript packages; this does not analyze Flutter code

## Stack

- Flutter and Dart; Android app blocking uses a native Accessibility Service
- Android platform code uses Kotlin and Gradle
- The surrounding Replit workspace uses pnpm and TypeScript for its shared services

## Where things live

- `artifacts/blockout/` — Flutter app and Android native implementation
- `artifacts/blockout/lib/` — timer, app selection, and Flutter UI
- `artifacts/blockout/android/` — installed-app discovery, timer persistence, and blocking screen

## Architecture decisions

- Selected app names and active session deadlines are stored locally on Android; no backend is needed.
- Blocking uses an Accessibility Service to detect a selected app opening and show a native blocking screen.
- The Android app picker only lists apps with a launcher activity.

## Product

- Users choose installed Android apps, select a focus duration, and end the session early or wait for the timer to finish.

## User preferences

- The user explicitly requested a Flutter mobile app.

## Gotchas

- The Flutter project requires the Flutter SDK and Android toolchain; this workspace does not provide an in-Replit Flutter preview.
- Android users must enable BlockOut in Accessibility settings for app blocking to work.

## Pointers

- `artifacts/blockout/README.md` — Flutter setup, app permissions, and platform scope
