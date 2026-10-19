# BlockOut

BlockOut is a Flutter app for Android. Choose apps, choose a focus duration, and
start a session. While a session is active, BlockOut uses an Android
Accessibility Service to detect when a selected app opens and show a blocking
screen until the timer ends.

## Run on Android

Install the Flutter SDK and Android toolchain, then run:

```sh
flutter pub get
flutter run
```

On the first session, enable **BlockOut App Blocking** in Android's Accessibility
settings. Android requires this permission for the app to detect which app is in
the foreground. BlockOut does not read screen contents or perform gestures.

The blocking session and selected app list are stored locally on the device.
Android lets users turn off Accessibility access or uninstall the app, so this
is a self-management aid rather than a device-admin restriction.

## Platform support

The current implementation is Android-only. iOS does not allow ordinary apps
to block other apps this way; that requires Apple's Screen Time APIs and
additional entitlements.
