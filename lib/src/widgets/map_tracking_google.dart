// lib/src/widgets/map_tracking_google.dart
//
// Widget reutilizable para tracking de un pedido en Google Maps.
//
// Forma parte de la OPCIÓN A del feature "flashdrop-map-options-prep".
// NO está integrado todavía en client_order_tracking_page.dart ni en
// delivery_orders_list_page.dart — esa integración la hace el dev a cargo
// cuando decida cuál opción conservar (A: google_maps_flutter, o B: flutter_map).
//
// Requisitos para que el widget funcione:
//   - google_maps_flutter en pubspec.yaml (ya agregado en esta rama).
//   - Android: API key configurada en android/local.properties con MAPS_API_KEY=AIza...
//     (build.gradle.kts la inyecta en AndroidManifest.xml vía manifestPlaceholders).
//   - iOS: API key pasada al build con --dart-define=GOOGLE_MAPS_API_KEY=AIza...
//     (AppDelegate.swift la lee de Info.plist, Info.plist la toma de $(GOOGLE_MAPS_API_KEY)).
//
// TODO cuando se integre:
//   - Reemplazar las coordenadas hardcoded (_pickup, _delivery) por
//     geocodificación real de las direcciones usando el package `geocoding`
//     (ya presente en pubspec.yaml) o Nominatim vía REST.
//   - Permitir `currentLocation` desde `geolocator.getPositionStream()` cuando
//     el dev integre al flujo del repartidor.
//   - Calcular la polyline con Directions API / Routes API si el D-1 del doc
//     requiere ruta óptima en lugar de línea recta.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

class MapTrackingWidget extends StatefulWidget {
  final String pickupAddress;
  final String deliveryAddress;
  final gmaps.LatLng? currentLocation;

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
  gmaps.GoogleMapController? _controller;

  // Coordenadas de ejemplo (Maipú -> Santiago centro). Sustituir por geocoding real.
  static const gmaps.LatLng _pickup = gmaps.LatLng(-33.4489, -70.6693);
  static const gmaps.LatLng _delivery = gmaps.LatLng(-33.4248, -70.6090);

  @override
  Widget build(BuildContext context) {
    return gmaps.GoogleMap(
      initialCameraPosition: const gmaps.CameraPosition(
        target: _pickup,
        zoom: 13,
      ),
      myLocationEnabled: widget.currentLocation != null,
      myLocationButtonEnabled: widget.currentLocation != null,
      markers: <gmaps.Marker>{
        const gmaps.Marker(
          markerId: gmaps.MarkerId('pickup'),
          position: _pickup,
          infoWindow: gmaps.InfoWindow(title: 'Retiro'),
        ),
        const gmaps.Marker(
          markerId: gmaps.MarkerId('delivery'),
          position: _delivery,
          infoWindow: gmaps.InfoWindow(title: 'Entrega'),
        ),
        if (widget.currentLocation != null)
          gmaps.Marker(
            markerId: const gmaps.MarkerId('me'),
            position: widget.currentLocation!,
          ),
      },
      polylines: <gmaps.Polyline>{
        const gmaps.Polyline(
          polylineId: gmaps.PolylineId('route'),
          points: [_pickup, _delivery],
          width: 4,
          color: Colors.blue,
        ),
      },
      onMapCreated: (c) => _controller = c,
    );
  }
}
