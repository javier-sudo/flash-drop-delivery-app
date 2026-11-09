import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';

/// Resuelve direcciones que llegan desde el catálogo y los pedidos.
///
/// Las coordenadas se validan dentro de Chile y se conservan durante la sesión
/// para que un mismo comercio no cambie de lugar entre recargas del mapa.
class RegisteredAddressResolver {
  RegisteredAddressResolver._();

  static final Map<String, Future<LatLng?>> _results = {};

  static Future<LatLng?> resolve(String address) {
    final normalized = _normalize(address);
    if (normalized.isEmpty) return Future.value(null);
    return _results.putIfAbsent(normalized, () async {
      final result = await _lookup(normalized);
      if (result == null) _results.remove(normalized);
      return result;
    });
  }

  /// Solo para tests.
  static void clearCache() => _results.clear();

  static Future<LatLng?> _lookup(String address) async {
    try {
      final results = await locationFromAddress(
        _chileQuery(address),
      ).timeout(const Duration(seconds: 8));
      if (results.isNotEmpty) {
        final location = results.first;
        if (_isInChile(location.latitude, location.longitude)) {
          return LatLng(location.latitude, location.longitude);
        }
      }
    } catch (_) {
      // Sin geocodificador (web, sin red): se resuelve abajo.
    }
    return Environment.useDemoMode ? demoPoint(address) : null;
  }

  /// Punto estable cerca de Santiago centro. Solo en modo demo, para que los
  /// mapas tengan algo que mostrar donde no hay geocodificador (web).
  static LatLng demoPoint(String address) {
    final h = address.codeUnits.fold<int>(0, (s, v) => s + v);
    return LatLng(
      -33.4372 + ((h % 17) - 8) * 0.0022,
      -70.6506 + ((h % 23) - 11) * 0.0022,
    );
  }

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String _chileQuery(String address) =>
      address.toLowerCase().contains('chile') ? address : '$address, Chile';

  static bool _isInChile(double latitude, double longitude) =>
      latitude >= -56 &&
      latitude <= -17 &&
      longitude >= -76 &&
      longitude <= -66;
}
