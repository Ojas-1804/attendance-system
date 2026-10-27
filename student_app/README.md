# Student App (Flutter)

Shows a student's profile, today's classes, subject-wise and overall attendance, history with filters,
and schedule (today / tomorrow / week). All numbers come from the backend - the app never calculates or
sends attendance values.

## First-time setup
```bash
cd student_app
flutter create --platforms=android,ios,web --project-name student_app .   # generates android/ ios/ web/ (keeps lib/ and pubspec.yaml)
flutter pub get
```
Android only, for local development over plain HTTP, add to `android/app/src/main/AndroidManifest.xml`
inside `<application ...>`:  `android:usesCleartextTraffic="true"`  (remove for production; use HTTPS).

## Run
Start the backend first (see root README), then:
```bash
# Android emulator (10.0.2.2 = your computer)
flutter run
# Real phone on the same Wi-Fi: use your computer's IP
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
# Chrome
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```
Demo login: `student@demo.edu` / `Student@12345` (after running `python seed.py` in `backend/`).
