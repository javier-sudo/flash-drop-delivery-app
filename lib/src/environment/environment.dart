class Environment {
  /// URL del API Gateway. Se cambia sin editar codigo:
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  static const String apiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const bool useDemoMode = bool.fromEnvironment(
    'USE_DEMO_MODE',
    defaultValue: false,
  );
}
