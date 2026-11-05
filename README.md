# Kagisho Connect — Mobile app

This is the Flutter parent/guardian app. The `web/` directory is Flutter's web runner support; it is not the separate staff website.

## Requirements
- Flutter SDK (Dart 3.4 or newer)
- Android Studio / Android SDK for Android builds, or Chrome for browser testing

## Run on Chrome
Windows: double-click `RUN_MOBILE_WINDOWS.bat`.
Or run from this folder:
```powershell
flutter pub get
flutter run -d chrome --web-hostname=localhost --web-port=8080 --dart-define-from-file=config/supabase.local.json
```

## Run on an Android device
Connect an Android device with USB debugging enabled, then:
```powershell
flutter pub get
flutter devices
flutter run --dart-define-from-file=config/supabase.local.json
```

## Build Android APK
```powershell
flutter build apk --release --dart-define-from-file=config/supabase.local.json
```

## Configuration
`config/supabase.local.json` contains the Supabase project URL and publishable key used by this copy. A publishable key is intended for client apps; never put a Supabase secret/service-role key in this file. Database access must be protected by Supabase RLS policies.

SQL migrations are in `database/`. Apply them to the intended Supabase project in the order indicated by their filenames and project documentation. Do not run migrations against production without reviewing them and taking a backup.

## Notes
Generated Flutter caches and build output were removed to keep the package clean. `flutter pub get` recreates required local dependencies. No UI redesign or feature changes were made.
