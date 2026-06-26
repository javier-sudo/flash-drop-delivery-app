import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class AddressSelectorPage extends StatefulWidget {
  const AddressSelectorPage({super.key});

  @override
  State<AddressSelectorPage> createState() => _AddressSelectorPageState();
}

class _AddressSelectorPageState extends State<AddressSelectorPage> {
  final _searchController = TextEditingController();
  final _mapController = MapController();
  final _box = GetStorage();

  LatLng _center = const LatLng(-33.4372, -70.6506); // Santiago por defecto
  String _addressText = '';
  bool _reverseGeocoding = false;
  bool _forwardGeocoding = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCurrentAddress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _loadCurrentAddress() {
    final raw = _box.read('delivery_address');
    if (raw is Map) {
      final lat = (raw['lat'] as num?)?.toDouble();
      final lng = (raw['lng'] as num?)?.toDouble();
      final addr = raw['address']?.toString() ?? '';
      if (lat != null && lng != null && addr.isNotEmpty) {
        _center = LatLng(lat, lng);
        _addressText = addr;
        _searchController.text = addr;
      }
    }
  }

  List<Map<String, dynamic>> get _savedAddresses {
    final raw = _box.read('saved_addresses');
    if (raw is List) {
      return raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  // Búsqueda por texto → mover mapa
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 5) return;
    _debounce = Timer(
      const Duration(milliseconds: 700),
      () => _forwardGeocode(query),
    );
  }

  Future<void> _forwardGeocode(String query) async {
    if (!mounted) return;
    setState(() => _forwardGeocoding = true);
    try {
      final results = await locationFromAddress('$query, Chile');
      if (!mounted || results.isEmpty) return;
      final loc = results.first;
      final newCenter = LatLng(loc.latitude, loc.longitude);
      _mapController.move(newCenter, 15);
      setState(() {
        _center = newCenter;
        _addressText = query;
        _forwardGeocoding = false;
      });
    } catch (_) {
      if (mounted) setState(() => _forwardGeocoding = false);
    }
  }

  // Mapa arrastrado → geocodificación inversa
  void _onMapMoved(LatLng center) {
    _center = center;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 700),
      _reverseGeocode,
    );
  }

  Future<void> _reverseGeocode() async {
    if (!mounted) return;
    setState(() => _reverseGeocoding = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        _center.latitude,
        _center.longitude,
      );
      if (!mounted) return;
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.thoroughfare ?? '').isNotEmpty)
            '${p.thoroughfare}${(p.subThoroughfare ?? '').isNotEmpty ? ' ${p.subThoroughfare}' : ''}',
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
          if ((p.locality ?? '').isNotEmpty) p.locality!,
        ];
        final addr = parts.join(', ');
        setState(() {
          _addressText = addr.isNotEmpty ? addr : _addressText;
          if (addr.isNotEmpty) _searchController.text = addr;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _reverseGeocoding = false);
  }

  void _selectSavedAddress(Map<String, dynamic> saved) {
    final lat = (saved['lat'] as num?)?.toDouble();
    final lng = (saved['lng'] as num?)?.toDouble();
    final addr = saved['address']?.toString() ?? '';
    if (lat != null && lng != null) {
      final newCenter = LatLng(lat, lng);
      _mapController.move(newCenter, 15);
      setState(() {
        _center = newCenter;
        _addressText = addr;
        _searchController.text = addr;
      });
    }
  }

  Future<void> _confirmAddress() async {
    if (_addressText.trim().isEmpty) {
      Get.snackbar(
        'Falta la dirección',
        'Mueve el mapa o escribe una dirección.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await _box.write('delivery_address', {
      'address': _addressText.trim(),
      'label': null,
      'lat': _center.latitude,
      'lng': _center.longitude,
    });
    Get.back();
  }

  Future<void> _saveWithLabel(String label) async {
    if (_addressText.trim().isEmpty) return;
    final entry = {
      'address': _addressText.trim(),
      'label': label,
      'lat': _center.latitude,
      'lng': _center.longitude,
    };
    await _box.write('delivery_address', entry);

    final saved = _savedAddresses;
    saved.removeWhere((e) => e['label'] == label);
    saved.insert(0, entry);
    if (saved.length > 5) saved.removeLast();
    await _box.write('saved_addresses', saved);

    Get.snackbar(
      'Guardada',
      '"$label" guardada correctamente.',
      snackPosition: SnackPosition.BOTTOM,
    );
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final saved = _savedAddresses;

    return Scaffold(
      appBar: AppBar(title: const Text('¿A dónde entregamos?')),
      body: Column(
        children: [
          // ── Barra de búsqueda ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: _forwardGeocode,
              decoration: InputDecoration(
                hintText: 'Buscar calle, número o barrio...',
                prefixIcon: _forwardGeocoding
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFFFB300),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // ── Mapa con pin central ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 230,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: 15,
                        onPositionChanged: (camera, hasGesture) {
                          if (hasGesture) _onMapMoved(camera.center);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.javier.proyecto_app_delivery_gessof',
                        ),
                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                              onTap: () => launchUrl(
                                Uri.parse(
                                  'https://openstreetmap.org/copyright',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Pin centrado
                    const IgnorePointer(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_pin,
                              color: Color(0xFFFFB300),
                              size: 52,
                            ),
                            SizedBox(height: 26),
                          ],
                        ),
                      ),
                    ),
                    // Indicador de geocodificación
                    if (_reverseGeocoding)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Detectando dirección...',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Hint para arrastrar
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Arrastra el mapa para ajustar',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6A6F77),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Dirección detectada ───────────────────────────
          if (_addressText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFFFFB300),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _addressText,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Direcciones guardadas ─────────────────────────
          if (saved.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.bookmark_outline,
                    size: 15,
                    color: Color(0xFF9EA5AD),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Guardadas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: saved.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = saved[i];
                  final label = s['label']?.toString() ?? 'Dirección';
                  final icon = label == 'Casa'
                      ? Icons.home_outlined
                      : label == 'Trabajo'
                          ? Icons.work_outline
                          : Icons.bookmark_outline;
                  return ActionChip(
                    avatar: Icon(icon, size: 15),
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _selectSavedAddress(s),
                  );
                },
              ),
            ),
          ],

          const Spacer(),

          // ── Acciones inferiores ───────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Guardar como Casa / Trabajo
                  if (_addressText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Text(
                            'Guardar como:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6A6F77),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _QuickSaveChip(
                            label: 'Casa',
                            icon: Icons.home_outlined,
                            onTap: () => _saveWithLabel('Casa'),
                          ),
                          const SizedBox(width: 8),
                          _QuickSaveChip(
                            label: 'Trabajo',
                            icon: Icons.work_outline,
                            onTap: () => _saveWithLabel('Trabajo'),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed:
                          _addressText.isNotEmpty ? _confirmAddress : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Usar esta dirección'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickSaveChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickSaveChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD6D8DC)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFF4A4A4A)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
