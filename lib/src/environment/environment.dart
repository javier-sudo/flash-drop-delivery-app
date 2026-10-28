class Environment {
  /// Gateway de desarrollo. Para el emulador Android local usar:
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  static const String apiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://76-13-168-23.sslip.io',
  );
}
