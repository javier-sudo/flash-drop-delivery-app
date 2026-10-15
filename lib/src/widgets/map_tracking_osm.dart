// lib/src/widgets/map_tracking_osm.dart
//
// Widget reutilizable para tracking de un pedido en un mapa
// OpenStreetMap vía flutter_map.
//
// Forma parte de la OPCIÓN B del feature "flashdrop-map-options-prep".
// NO está integrado todavía en client_order_tracking_page.dart ni en
// delivery_orders_list_page.dart — esa integración la hace el dev a cargo
// cuando decida cuál opción conservar (A: google_maps_flutter, o B: flutter_map).
//
// Requisitos:
//   - flutter_map, latlong2, geocoding: ya presentes en pubspec.yaml.
//   - geolocator: agregado en esta rama, para "my location" del repartidor.
//   - Atribución obligatoria "OpenStreetMap contributors" — la incluye el
//     RichAttributionWidget, no la quites (requisito de la ODbL).
//
// TODO cuando se integre:
//   - Reemplazar las coordenadas hardcoded (_pickup, _delivery) por
//     geocodificación real usando el package `geocoding` (ya presente)
//     con pickupAddress/deliveryAddress.
//   - Permitir `currentLocation` desde geolocator.getPositionStream().
//   - Calcular polyline con OSRM público
//     (https://router.project-osrm.org/route/v1/driving/...) si el D-1
//     del doc requiere ruta óptima en lugar de línea recta.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapTrackingWidget extends StatefulWidget {
  final String pickupAddress;
  final String deliveryAddress;
  final LatLng? currentLocation;

  const MapTrackingWidget({
    super.key,
    required this.pickupAddress,
    required this.deliveryAddress,
    this.currentLocation,
  });

  @override
  State<MapTrackingWidget> createState() => _MapTrackingWidgetState();
}

class _MapTrackingWidgetState extends State<MapTrackingWidget> {
  final MapController _mapController = MapController();

  // Coordenadas de ejemplo (Maipú -> Santiago centro). Sustituir por geocoding real.
  static const LatLng _pickup = LatLng(-33.4489, -70.6693);
  static const LatLng _delivery = LatLng(-33.4248, -70.6090);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _pickup,
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          // OpenStreetMap público. userAgentPackageName es OBLIGATORIO por
          // la política de uso de tiles OSM.
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.javier.proyecto_app_delivery_gessof',
          maxNativeZoom: 19,
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _pickup,
              width: 40,
              height: 40,
              child: const Icon(Icons.store, color: Colors.orange, size: 36),
            ),
            Marker(
              point: _delivery,
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Colors.red, size: 36),
            ),
            if (widget.currentLocation != null)
              Marker(
                point: widget.currentLocation!,
                width: 40,
                height: 40,
                child: const Icon(Icons.my_location, color: Colors.blue, size: 36),
              ),
          ],
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: [_pickup, _delivery],
              strokeWidth: 4,
              color: Colors.blue,
            ),
          ],
        ),
        // Atribución OBLIGATORIA por la licencia ODbL de OpenStreetMap.
        // Quitar este widget infringe la licencia.
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}
