// lib/src/widgets/map_tracking_osm.dart
//
// Widget reutilizable para tracking de un pedido en un mapa
// OpenStreetMap vía flutter_map.
//
// Forma parte de la OPCIÓN B del feature "flashdrop-map-options-prep".
// La pantalla que lo usa resuelve las direcciones obtenidas desde FloCI a
// coordenadas antes de construir el widget. El mapa nunca inventa puntos de
// retiro o entrega: si no hay coordenadas, muestra solo la zona base.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapTrackingWidget extends StatelessWidget {
  final LatLng? pickupLocation;
  final LatLng? deliveryLocation;
  final LatLng? currentLocation;

  const MapTrackingWidget({
    super.key,
    this.pickupLocation,
    this.deliveryLocation,
    this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      if (pickupLocation != null) pickupLocation!,
      if (deliveryLocation != null) deliveryLocation!,
    ];
    final center =
        deliveryLocation ??
        pickupLocation ??
        currentLocation ??
        const LatLng(-33.4372, -70.6506);

    return FlutterMap(
      key: ValueKey(
        points.map((point) => '${point.latitude},${point.longitude}').join('|'),
      ),
      options: MapOptions(
        initialCenter: center,
        initialZoom: points.length <= 1 ? 14 : 13,
        initialCameraFit: points.length > 1
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(points),
                padding: const EdgeInsets.all(48),
              )
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.javier.proyecto_app_delivery_gessof',
          maxNativeZoom: 19,
        ),
        MarkerLayer(
          markers: [
            if (pickupLocation != null)
              _marker(
                pickupLocation!,
                Icons.storefront,
                const Color(0xFF16824B),
              ),
            if (deliveryLocation != null)
              _marker(deliveryLocation!, Icons.home, const Color(0xFF1769C2)),
            if (currentLocation != null)
              Marker(
                point: currentLocation!,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 36,
                ),
              ),
          ],
        ),
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4,
                color: const Color(0xFFFFB300),
              ),
            ],
          ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  static Marker _marker(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
