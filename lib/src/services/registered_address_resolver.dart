import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

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
    return _results.putIfAbsent(normalized, () => _lookup(normalized));
  }

  static Future<LatLng?> _lookup(String address) async {
    try {
      final results = await locationFromAddress(
        _chileQuery(address),
      ).timeout(const Duration(seconds: 8));
      if (results.isEmpty) return null;

      final location = results.first;
      if (!_isInChile(location.latitude, location.longitude)) return null;
      return LatLng(location.latitude, location.longitude);
    } catch (_) {
      return null;
    }
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
