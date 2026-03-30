# easytime_online

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Camera Integration Notes

- Added `camera` package to enable live in-page camera preview on the Check In/Check Out screen.
- After pulling changes run:

```bash
flutter pub get
```

- Android: camera permission was added to `android/app/src/main/AndroidManifest.xml`.
- iOS: if you run on iOS, ensure `NSCameraUsageDescription` is present in `ios/Runner/Info.plist`.

Behavior: the app shows a live selfie preview inside the circular avatar; tapping the large button still opens the image picker as a fallback. The photo is captured automatically from the preview when you tap the Check In / Check Out button.
