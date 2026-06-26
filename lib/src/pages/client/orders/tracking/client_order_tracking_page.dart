import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

class ClientOrderTrackingPage extends StatefulWidget {
  const ClientOrderTrackingPage({super.key});

  @override
  State<ClientOrderTrackingPage> createState() =>
      _ClientOrderTrackingPageState();
}

class _ClientOrderTrackingPageState extends State<ClientOrderTrackingPage> {
  final _appProvider = AppProvider();

  late final int _orderId;
  Map<String, dynamic> _order = {};
  bool _loading = true;
  String? _error;
  Timer? _timer;

  LatLng? _pickupCoord;
  LatLng? _deliveryCoord;
  bool _geocoding = false;

  @override
  void initState() {
    super.initState();
    _orderId = (Get.arguments as int?) ?? 0;
    _loadOrder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final detail = await _appProvider.getOrderDetail(_orderId);
      if (!mounted) return;
      setState(() {
        _order = detail;
        _loading = false;
      });
      _scheduleRefreshIfActive();
      if (!_geocoding) await _geocodeAddresses();
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'No se pudo cargar el pedido';
          _loading = false;
        });
      }
    }
  }

  void _scheduleRefreshIfActive() {
    _timer?.cancel();
    if (!_isDelivered) {
      _timer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _loadOrder(silent: true),
      );
    }
  }

  bool get _isDelivered =>
      '${_order['status']}'.toLowerCase().contains('entregado');

  int get _currentStep {
    final s = '${_order['status']}'.toLowerCase();
    if (s.contains('entregado')) return 3;
    if (s.contains('camino')) return 2;
    if (s.contains('listo') || s.contains('preparando')) return 1;
    return 0;
  }

  String get _pickupAddress {
    if (_order['restaurantAddress'] is String &&
        (_order['restaurantAddress'] as String).isNotEmpty) {
      return _order['restaurantAddress'] as String;
    }
    final restaurant = _order['restaurant'];
    if (restaurant is Map) {
      final addr = restaurant['address']?.toString() ?? '';
      if (addr.isNotEmpty) return addr;
    }
    final items = _order['items'] as List?;
    if (items != null && items.isNotEmpty) {
      final first = items.first as Map?;
      final addr = first?['restaurantAddress']?.toString() ?? '';
      if (addr.isNotEmpty) return addr;
    }
    return '';
  }

  Future<void> _geocodeAddresses() async {
    _geocoding = true;
    final delivery = '${_order['address'] ?? ''}';
    final pickup = _pickupAddress;

    if (delivery.isNotEmpty) {
      _deliveryCoord = await _geocode(delivery);
    }
    if (pickup.isNotEmpty && pickup != delivery) {
      _pickupCoord = await _geocode(pickup);
    }
    if (mounted) setState(() {});
    _geocoding = false;
  }

  Future<LatLng> _geocode(String address) async {
    try {
      final results = await locationFromAddress('$address, Chile');
      if (results.isNotEmpty) {
        return LatLng(results.first.latitude, results.first.longitude);
      }
    } catch (_) {}
    final hash = address.codeUnits.fold<int>(0, (s, v) => s + v);
    return LatLng(
      -33.4372 + ((hash % 17) - 8) * 0.002,
      -70.6506 + ((hash % 23) - 11) * 0.002,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'Seguimiento' : '${_order['code'] ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadOrder,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 52),
              const SizedBox(height: 12),
              Text(_error!),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _loadOrder,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final items = List<Map<String, dynamic>>.from(_order['items'] ?? []);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _StatusHeader(statusText: '${_order['status']}', step: _currentStep),
        const SizedBox(height: 20),
        _StatusTimeline(currentStep: _currentStep),
        const SizedBox(height: 22),
        _TrackingMap(
          pickupCoord: _pickupCoord,
          deliveryCoord: _deliveryCoord,
          pickupAddress: _pickupAddress,
          deliveryAddress: '${_order['address'] ?? ''}',
        ),
        const SizedBox(height: 18),
        _InfoCard(
          icon: Icons.location_on_outlined,
          title: 'Dirección de entrega',
          value: '${_order['address'] ?? '-'}',
        ),
        if (_order['estimatedMinutes'] != null) ...[
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.schedule,
            title: 'Tiempo estimado',
            value: '${_order['estimatedMinutes']} min',
          ),
        ],
        if (_order['paymentMethod'] != null) ...[
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.payments_outlined,
            title: 'Forma de pago',
            value: '${_order['paymentMethod']}',
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Tu pedido',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...items.map((item) => _ItemRow(item: item)),
        const Divider(height: 28),
        _TotalRow(label: 'Subtotal', value: _order['subtotal']),
        const SizedBox(height: 6),
        _TotalRow(label: 'Envío', value: _order['deliveryFee']),
        const SizedBox(height: 4),
        _TotalRow(label: 'Total', value: _order['total'], strong: true),
      ],
    );
  }
}

// ─── Status header ────────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final String statusText;
  final int step;

  const _StatusHeader({required this.statusText, required this.step});

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg, description) = _meta(step);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, Color, String) _meta(int step) {
    return switch (step) {
      0 => (
        Icons.receipt_long_outlined,
        const Color(0xFF1769C2),
        const Color(0xFFEEF3FF),
        'El restaurante recibió tu pedido.',
      ),
      1 => (
        Icons.soup_kitchen_outlined,
        const Color(0xFF8A5700),
        const Color(0xFFFFF8E1),
        'El local está preparando tu pedido.',
      ),
      2 => (
        Icons.delivery_dining,
        const Color(0xFF1565C0),
        const Color(0xFFE8F0FE),
        'Tu pedido está en camino.',
      ),
      _ => (
        Icons.check_circle_outline,
        const Color(0xFF12643D),
        const Color(0xFFE6F4ED),
        '¡Tu pedido fue entregado! Buen provecho.',
      ),
    };
  }
}

// ─── Status timeline ──────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final int currentStep;

  const _StatusTimeline({required this.currentStep});

  static const _steps = [
    (Icons.receipt_long_outlined, 'Recibido'),
    (Icons.soup_kitchen_outlined, 'Preparando'),
    (Icons.delivery_dining, 'En camino'),
    (Icons.check_circle_outline, 'Entregado'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final filled = (i ~/ 2) < currentStep;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: filled
                      ? const Color(0xFFFFB300)
                      : const Color(0xFFE0E2E6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }
          final step = i ~/ 2;
          final done = step <= currentStep;
          final active = step == currentStep;
          final (icon, label) = _steps[step];
          return _StepDot(
            icon: icon,
            label: label,
            done: done,
            active: active,
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final bool active;

  const _StepDot({
    required this.icon,
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color iconColor;
    if (active) {
      bg = const Color(0xFFFFB300);
      iconColor = Colors.white;
    } else if (done) {
      bg = const Color(0xFF12643D);
      iconColor = Colors.white;
    } else {
      bg = const Color(0xFFE8EAED);
      iconColor = const Color(0xFF9EA5AD);
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: active ? 48 : 38,
          height: active ? 48 : 38,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.45),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: iconColor, size: active ? 24 : 18),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w900 : FontWeight.w400,
            color:
                done ? const Color(0xFF1E2025) : const Color(0xFFB0B5BB),
          ),
        ),
      ],
    );
  }
}

// ─── Tracking map ─────────────────────────────────────────────────────────────

class _TrackingMap extends StatelessWidget {
  final LatLng? pickupCoord;
  final LatLng? deliveryCoord;
  final String pickupAddress;
  final String deliveryAddress;

  const _TrackingMap({
    required this.pickupCoord,
    required this.deliveryCoord,
    required this.pickupAddress,
    required this.deliveryAddress,
  });

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      if (pickupCoord != null) pickupCoord!,
      if (deliveryCoord != null) deliveryCoord!,
    ];
    final markers = <Marker>[
      if (pickupCoord != null)
        _buildMarker(
          pickupCoord!,
          Icons.storefront,
          const Color(0xFF16824B),
        ),
      if (deliveryCoord != null)
        _buildMarker(
          deliveryCoord!,
          Icons.home,
          const Color(0xFF1769C2),
        ),
    ];
    final center =
        deliveryCoord ?? pickupCoord ?? const LatLng(-33.4372, -70.6506);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mapa de seguimiento',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            _LegendItem(
              color: const Color(0xFF16824B),
              label: 'Restaurante',
            ),
            const SizedBox(width: 12),
            _LegendItem(
              color: const Color(0xFF1769C2),
              label: 'Tu dirección',
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              key: ValueKey(
                points
                    .map((p) => '${p.latitude},${p.longitude}')
                    .join('|'),
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
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.javier.proyecto_app_delivery_gessof',
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
                MarkerLayer(markers: markers),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://openstreetmap.org/copyright'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Marker _buildMarker(LatLng point, IconData icon, Color color) {
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ─── Info / item widgets ──────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF9EA5AD)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9EA5AD),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${item['quantity']}x',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${item['name']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(_clp(item['total'])),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool strong;

  const _TotalRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: strong ? 18 : 15,
      fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(_clp(value), style: style),
      ],
    );
  }
}

String _clp(dynamic value) {
  final number = double.tryParse('$value') ?? 0;
  return '\$${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';
}
