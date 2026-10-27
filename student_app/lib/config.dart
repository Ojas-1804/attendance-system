/// Backend URL. Override at build/run time (never hard-code secrets in the app):
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
/// Default 10.0.2.2 is the Android emulator's alias for your computer's localhost.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
