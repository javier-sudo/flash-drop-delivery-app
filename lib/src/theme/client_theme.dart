import 'package:flutter/material.dart';

/// Tokens del rediseño del cliente ("Flash Drop App redesign"): fondo crema,
/// azul marino como tinta, amarillo de marca y azul de acento.
class FD {
  static const navy = Color(0xFF0E1A35);
  static const yellow = Color(0xFFFFC72C);
  static const blue = Color(0xFF1F6BFF);
  static const cream = Color(0xFFF5F3EE);
  static const soft = Color(0xFFFFF4CC);
  static const muted = Color(0xFF6B7385);
  static const subtle = Color(0xFF8A91A0);
  static const line = Color(0xFFEFECE4);
  static const brown = Color(0xFF5A4300);
  static const danger = Color(0xFFC62828);

  static const font = 'Archivo';

  /// Títulos de pantalla y de sección: Archivo itálica, muy gruesa.
  static TextStyle display(double size, {Color color = navy}) => TextStyle(
    fontFamily: font,
    fontSize: size,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
    color: color,
    height: 1.1,
  );

  static TextStyle section(double size) => TextStyle(
    fontFamily: font,
    fontSize: size,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: navy,
  );

  static TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = navy,
    double? height,
  }) => TextStyle(
    fontFamily: font,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  /// Sombra suave de las tarjetas blancas.
  static const cardShadow = [
    BoxShadow(color: Color(0x0F0E1A35), blurRadius: 10, offset: Offset(0, 2)),
  ];

  static ThemeData theme(ThemeData base) {
    final scheme = base.colorScheme.copyWith(
      primary: yellow,
      onPrimary: navy,
      secondary: navy,
      surface: Colors.white,
      onSurface: navy,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: cream,
      textTheme: base.textTheme.apply(
        fontFamily: font,
        bodyColor: navy,
        displayColor: navy,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: cream,
        foregroundColor: navy,
        titleTextStyle: section(19),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: navy,
          textStyle: text(15, weight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: text(13, weight: FontWeight.w700),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(backgroundColor: navy),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: navy),
    );
  }
}

/// Aplica el tema del rediseño solo a las pantallas del cliente (local y
/// repartidor conservan el suyo).
class ClientTheme extends StatelessWidget {
  final Widget child;
  const ClientTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Theme(data: FD.theme(Theme.of(context)), child: child);
}
