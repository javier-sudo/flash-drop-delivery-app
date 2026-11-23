import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreDeliveryCoveragePage extends StatefulWidget {
  const StoreDeliveryCoveragePage({super.key, this.provider});
  final AppProvider? provider;

  @override
  State<StoreDeliveryCoveragePage> createState() =>
      _StoreDeliveryCoveragePageState();
}

class _StoreDeliveryCoveragePageState extends State<StoreDeliveryCoveragePage> {
  final _form = GlobalKey<FormState>();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _radius = TextEditingController();
  late final _api =
      widget.provider ??
      (Get.isRegistered<AppProvider>()
          ? Get.find<AppProvider>()
          : AppProvider());
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _name = 'Mi comercio';

  LatLng? get _pin {
    final lat = double.tryParse(_latitude.text.replaceAll(',', '.'));
    final lng = double.tryParse(_longitude.text.replaceAll(',', '.'));
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = await _api.getMyRestaurant();
      if (!mounted) return;
      setState(() {
        _name = '${store['name'] ?? 'Mi comercio'}';
        _latitude.text = '${store['latitude'] ?? ''}';
        _longitude.text = '${store['longitude'] ?? ''}';
        _radius.text = '${store['deliveryRadiusKm'] ?? ''}';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo cargar la zona de despacho.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final pin = _pin!;
    final radius = double.parse(_radius.text.replaceAll(',', '.'));
    setState(() {
      _saving = true;
      _error = null;
    });
    var locationSaved = false;
    try {
      await _api.updateStoreLocation(
        latitude: pin.latitude,
        longitude: pin.longitude,
      );
      locationSaved = true;
      await _api.updateStoreDeliveryRadius(radius);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zona de despacho guardada')),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = locationSaved
              ? 'Ubicacion guardada, pero no se pudo guardar el radio. Reintenta.'
              : 'No se pudo guardar. Revisa la conexion y reintenta.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _coordinateError(String? text, double limit) {
    final value = double.tryParse((text ?? '').replaceAll(',', '.'));
    return value == null || !value.isFinite || value.abs() > limit
        ? 'Coordenada invalida'
        : null;
  }

  String? _radiusError(String? text) {
    final raw = (text ?? '').replaceAll(',', '.');
    final value = double.tryParse(raw);
    return value == null ||
            !value.isFinite ||
            value < 1 ||
            value > 50 ||
            !RegExp(r'^\d{1,2}(\.\d{1,2})?$').hasMatch(raw)
        ? 'Entre 1 y 50 km, hasta 2 decimales'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final pin = _pin;
    final radius = double.tryParse(_radius.text.replaceAll(',', '.'));
    return Scaffold(
      appBar: AppBar(title: const Text('Zona de despacho')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(_name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _saving ? null : _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Recargar'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 260,
                    child: FlutterMap(
                      key: const ValueKey('store-coverage-map'),
                      options: MapOptions(
                        initialCenter: pin ?? const LatLng(-33.4372, -70.6506),
                        initialZoom: 11,
                        onTap: _saving
                            ? null
                            : (_, point) => setState(() {
                                _latitude.text = point.latitude.toStringAsFixed(
                                  6,
                                );
                                _longitude.text = point.longitude
                                    .toStringAsFixed(6);
                              }),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.javier.proyecto_app_delivery_gessof',
                        ),
                        if (pin != null &&
                            radius != null &&
                            radius.isFinite &&
                            radius >= 1 &&
                            radius <= 50)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: pin,
                                radius: radius * 1000,
                                useRadiusInMeter: true,
                                color: const Color(0x222775C8),
                                borderColor: const Color(0xFF2775C8),
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                        if (pin != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: pin,
                                child: const Icon(
                                  Icons.storefront,
                                  size: 32,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                            ],
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
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _latitude,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Latitud del local',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => _coordinateError(v, 90),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _longitude,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Longitud del local',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => _coordinateError(v, 180),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _radius,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Radio de despacho',
                      suffixText: 'km',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _radiusError,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [5, 10, 15, 20]
                        .map(
                          (km) => ChoiceChip(
                            label: Text('$km km'),
                            selected: radius == km,
                            onSelected: _saving
                                ? null
                                : (_) => setState(() => _radius.text = '$km'),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando...' : 'Guardar zona'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
