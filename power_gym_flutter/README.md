# POWER GYM — Flutter Android App

A dark black/red bilingual (English/Amharic) starter app for a gym. Includes:
- Dashboard summary
- Workout guide cards
- Member progress records (body weight + notes)
- Attendance check-ins (one check-in per member per day)
- Member register
- Payment tracking (recording a payment extends the member's paid-through date by 30 days)
- Local persistence with `shared_preferences`
- Language toggle in the top app bar
- Gym contact shown on dashboard: `0942851168`

## Requirements
- Flutter SDK (stable)
- Android Studio and Android SDK, or Flutter configured with Android build tools

## Create and run
1. Extract this ZIP.
2. Open a terminal in the `power_gym_flutter` folder.
3. Run:
   ```bash
   flutter create . --platforms=android
   flutter pub get
   flutter run
   ```
   If prompted to overwrite generated platform files, keep your generated Android platform files; this project supplies the Dart app and package config.
4. Connect an Android phone with USB debugging enabled, or start an Android emulator.

## Build an APK
From the project folder:
```bash
flutter build apk --release
```
The APK is normally written to:
`build/app/outputs/flutter-apk/app-release.apk`

To build a Play Store bundle:
```bash
flutter build appbundle --release
```

## Important notes
- This source ZIP does not contain a prebuilt APK. Build the APK using Flutter on a computer with Android build tools installed.
- The app stores records locally on the device. There is no cloud sync, online login, or automatic backup yet. Uninstalling the app or clearing its data can remove saved records.
- Payment recording is a manual register only; it does not charge a bank account or mobile-money wallet.
- The workout examples are general fitness suggestions, not individual medical or training advice.
- The sample member can be deleted from the Members screen.
