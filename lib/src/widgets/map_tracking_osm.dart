// lib/src/widgets/map_tracking_osm.dart
//
// Mapa de seguimiento de un pedido con OpenStreetMap (flutter_map).
// Recibe las coordenadas ya geocodificadas del local y de la entrega; mientras
// no lleguen muestra Santiago centro. Con ambos puntos pide el recorrido por
// calles a OSRM y, si no responde, dibuja la línea recta como estimación.
//
// Atribución obligatoria "OpenStreetMap contributors" (licencia ODbL): la
// incluye el RichAttributionWidget, no la quites.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/illustration.dart';

class MapTrackingWidget extends StatefulWidget {
  final LatLng? pickupLocation;
  final LatLng? deliveryLocation;
  final LatLng? currentLocation;

  /// true mientras la pantalla aún geocodifica las direcciones.
  final bool resolving;

  /// Permite reemplazar OSRM (tests o sin red). Devuelve [] si no hay ruta.
  final Future<List<LatLng>> Function(LatLng from, LatLng to)? routeLoader;

  const MapTrackingWidget({
    super.key,
    this.pickupLocation,
    this.deliveryLocation,
    this.currentLocation,
    this.resolving = false,
    this.routeLoader,
  });

  @override
  State<MapTrackingWidget> createState() => _MapTrackingWidgetState();
}

class _MapTrackingWidgetState extends State<MapTrackingWidget> {
  static const LatLng _santiago = LatLng(-33.4372, -70.6506);

  List<LatLng> _route = const [];
  bool _loadingRoute = false;
  bool _routeFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRoute());
  }

  @override
  void didUpdateWidget(covariant MapTrackingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickupLocation != widget.pickupLocation ||
        oldWidget.deliveryLocation != widget.deliveryLocation) {
      unawaited(_loadRoute());
    }
  }

  Future<void> _loadRoute() async {
    final from = widget.pickupLocation;
    final to = widget.deliveryLocation;
    if (from == null || to == null) {
      if (mounted) setState(() => _route = const []);
      return;
    }
    setState(() {
      _loadingRoute = true;
      _routeFailed = false;
    });
    final loader = widget.routeLoader ?? roadRoute;
    final route = await loader(from, to);
    // Si cambiaron los puntos mientras tanto, esta respuesta ya no sirve.
    if (!mounted ||
        from != widget.pickupLocation ||
        to != widget.deliveryLocation) {
      return;
    }
    setState(() {
      _route = route;
      _loadingRoute = false;
      _routeFailed = route.isEmpty;
    });
  }

  String? get _message {
    if (widget.resolving) return null;
    if (widget.pickupLocation == null || widget.deliveryLocation == null) {
      return 'No pudimos ubicar una de las direcciones en el mapa.';
    }
    if (_routeFailed) return 'Mostrando recorrido estimado.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final points = [?widget.pickupLocation, ?widget.deliveryLocation];
    final camera = [...points, ?widget.currentLocation];
    final line = _route.isNotEmpty ? _route : points;
    final message = _message;

    return Stack(
      children: [
        FlutterMap(
          // La key fuerza a recalcular la cámara cuando llegan las coordenadas.
          key: ValueKey(
            camera.map((p) => '${p.latitude},${p.longitude}').join('|'),
          ),
          options: MapOptions(
            initialCenter: camera.isEmpty ? _santiago : camera.first,
            initialZoom: 13,
            initialCameraFit: camera.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(camera),
                    padding: const EdgeInsets.all(40),
                  )
                : null,
          ),
          children: [
            TileLayer(
              // OpenStreetMap público. userAgentPackageName es OBLIGATORIO por
              // la política de uso de tiles OSM.
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.javier.proyecto_app_delivery_gessof',
              maxNativeZoom: 19,
            ),
            if (line.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: line,
                    strokeWidth: 5,
                    color: const Color(0xFF1769C2),
                    borderStrokeWidth: 2,
                    borderColor: Colors.white.withValues(alpha: 0.8),
                    // Punteada mientras sea solo la estimación en línea recta.
                    pattern: _route.isEmpty
                        ? StrokePattern.dashed(segments: const [10, 8])
                        : const StrokePattern.solid(),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (widget.pickupLocation != null)
                  Marker(
                    point: widget.pickupLocation!,
                    width: 44,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const MapPin(MapPinKind.store, size: 44),
                  ),
                if (widget.deliveryLocation != null)
                  Marker(
                    point: widget.deliveryLocation!,
                    width: 44,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const MapPin(MapPinKind.home, size: 44),
                  ),
                if (widget.currentLocation != null)
                  Marker(
                    point: widget.currentLocation!,
                    width: 48,
                    height: 52,
                    alignment: Alignment.topCenter,
                    child: const MapPin(MapPinKind.rider, size: 48),
                  ),
              ],
            ),
            // Atribución OBLIGATORIA por la licencia ODbL de OpenStreetMap.
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if (widget.resolving || _loadingRoute)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (message != null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Recorrido en auto entre dos puntos según OSRM. [] si falla o no hay ruta.
Future<List<LatLng>> roadRoute(
  LatLng from,
  LatLng to, {
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  try {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/'
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
      const {'overview': 'full', 'geometries': 'geojson'},
    );
    final response = await httpClient
        .get(uri)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return const [];
    return parseOsrmRoute(jsonDecode(response.body));
  } catch (e) {
    debugPrint('OSRM no respondió: $e');
    return const [];
  } finally {
    if (client == null) httpClient.close();
  }
}

/// Extrae la geometría GeoJSON ([lng, lat]) de la primera ruta de OSRM.
List<LatLng> parseOsrmRoute(Object? body) {
  final routes = body is Map ? body['routes'] : null;
  final first = routes is List && routes.isNotEmpty ? routes.first : null;
  final geometry = first is Map ? first['geometry'] : null;
  final coordinates = geometry is Map ? geometry['coordinates'] : null;
  if (coordinates is! List) return const [];
  return coordinates
      .whereType<List>()
      .where((p) => p.length >= 2 && p[0] is num && p[1] is num)
      .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
      .toList();
}
