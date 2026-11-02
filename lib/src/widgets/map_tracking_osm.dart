import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:proyecto_app_delivery_gessof/src/services/registered_address_resolver.dart';

class MapTrackingWidget extends StatefulWidget {
  final String pickupAddress;
  final String deliveryAddress;
  final LatLng? pickupCoordinates;
  final LatLng? deliveryCoordinates;
  final bool showCurrentLocation;

  const MapTrackingWidget({
    super.key,
    required this.pickupAddress,
    required this.deliveryAddress,
    this.pickupCoordinates,
    this.deliveryCoordinates,
    this.showCurrentLocation = false,
  });

  @override
  State<MapTrackingWidget> createState() => _MapTrackingWidgetState();
}

class _MapTrackingWidgetState extends State<MapTrackingWidget> {
  LatLng? _pickup;
  LatLng? _delivery;
  LatLng? _currentLocation;
  List<LatLng> _route = const [];
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveMap());
  }

  @override
  void didUpdateWidget(covariant MapTrackingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickupAddress != widget.pickupAddress ||
        oldWidget.deliveryAddress != widget.deliveryAddress ||
        oldWidget.pickupCoordinates != widget.pickupCoordinates ||
        oldWidget.deliveryCoordinates != widget.deliveryCoordinates ||
        oldWidget.showCurrentLocation != widget.showCurrentLocation) {
      unawaited(_resolveMap());
    }
  }

  Future<void> _resolveMap() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }
    final locations = await Future.wait([
      widget.pickupCoordinates == null
          ? _geocode(widget.pickupAddress)
          : Future.value(widget.pickupCoordinates),
      widget.deliveryCoordinates == null
          ? _geocode(widget.deliveryAddress)
          : Future.value(widget.deliveryCoordinates),
      if (widget.showCurrentLocation) _getCurrentLocation(),
    ]);
    final pickup = widget.pickupCoordinates ?? locations[0];
    final delivery = widget.deliveryCoordinates ?? locations[1];
    final current = widget.showCurrentLocation && locations.length > 2
        ? locations[2]
        : null;
    final route = pickup != null && delivery != null
        ? await _getRoadRoute(pickup, delivery)
        : const <LatLng>[];

    if (!mounted) return;
    setState(() {
      _pickup = pickup;
      _delivery = delivery;
      _currentLocation = current;
      _route = route;
      _loading = false;
      if (pickup == null || delivery == null) {
        _message = 'No pudimos ubicar una de las direcciones en el mapa.';
      } else if (route.isEmpty) {
        _message = 'Mostrando recorrido estimado.';
      }
    });
  }

  Future<LatLng?> _geocode(String address) async {
    return RegisteredAddressResolver.resolve(address);
  }

  Future<LatLng?> _getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<List<LatLng>> _getRoadRoute(LatLng from, LatLng to) async {
    try {
      final path =
          '/route/v1/driving/'
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final uri = Uri.https('router.project-osrm.org', path, const {
        'overview': 'full',
        'geometries': 'geojson',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final body = jsonDecode(response.body);
      final routes = body is Map ? body['routes'] : null;
      final geometry = routes is List && routes.isNotEmpty
          ? routes.first['geometry']
          : null;
      final coordinates = geometry is Map ? geometry['coordinates'] : null;
      if (coordinates is! List) return const [];
      return coordinates
          .whereType<List>()
          .where((point) => point.length >= 2)
          .map(
            (point) => LatLng(
              (point[1] as num).toDouble(),
              (point[0] as num).toDouble(),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final endpoints = <LatLng>[
      if (_pickup != null) _pickup!,
      if (_delivery != null) _delivery!,
      if (_currentLocation != null) _currentLocation!,
    ];
    final routePoints = _route.isNotEmpty ? _route : endpoints.take(2).toList();
    final initialCenter = endpoints.isNotEmpty
        ? endpoints.first
        : const LatLng(-33.4489, -70.6693);

    return Stack(
      children: [
        FlutterMap(
          key: ValueKey(
            '${widget.pickupAddress}:${widget.deliveryAddress}:$_currentLocation',
          ),
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: endpoints.length <= 1 ? 13 : 12,
            initialCameraFit: endpoints.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(endpoints),
                    padding: const EdgeInsets.all(40),
                  )
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.javier.proyecto_app_delivery_gessof',
              maxNativeZoom: 19,
            ),
            if (routePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 5,
                    color: const Color(0xFF0C9AF8),
                    borderStrokeWidth: 2,
                    borderColor: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (_pickup != null)
                  _marker(
                    _pickup!,
                    color: const Color(0xFF16824B),
                    icon: Icons.storefront,
                  ),
                if (_delivery != null)
                  _marker(
                    _delivery!,
                    color: const Color(0xFF0C9AF8),
                    icon: Icons.location_on,
                  ),
                if (_currentLocation != null)
                  _marker(
                    _currentLocation!,
                    color: const Color(0xFF171A1F),
                    icon: Icons.delivery_dining,
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if (_loading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (_message != null)
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
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Marker _marker(LatLng point, {required Color color, required IconData icon}) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
