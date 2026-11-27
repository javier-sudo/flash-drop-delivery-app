import 'package:flutter/material.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

class StoreSettingsPage extends StatefulWidget {
  const StoreSettingsPage({super.key, required this.provider});
  final AppProvider provider;

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  static const days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  Map<String, dynamic>? store;
  List<Map<String, dynamic>> hours = [];
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _setStore(Map<String, dynamic> value) {
    store = value;
    hours = (value['hours'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await widget.provider.getMyRestaurant();
      if (mounted) setState(() => _setStore(value));
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudo cargar la configuración del local.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _switch(bool value) async {
    setState(() => busy = true);
    try {
      final result = await widget.provider.updateMyRestaurantOpen(value);
      if (mounted) setState(() => _setStore(result));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cambiar la disponibilidad.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      final result = await widget.provider.updateMyRestaurantHours(hours);
      if (mounted) {
        setState(() => _setStore(result));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Horarios guardados.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron guardar los horarios. Revisa los tramos e intenta nuevamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addHours() async {
    var day = 1;
    final selectedDay = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Día de atención'),
          content: DropdownButton<int>(
            value: day,
            isExpanded: true,
            items: [
              for (var i = 1; i <= 7; i++)
                DropdownMenuItem(value: i, child: Text(days[i - 1])),
            ],
            onChanged: (value) => setDialogState(() => day = value ?? day),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, day),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
    if (selectedDay == null || !mounted) return;
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Hora de apertura',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Hora de cierre',
    );
    if (end == null || !mounted) return;
    String formatted(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (start == end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La apertura y el cierre deben ser distintos.'),
        ),
      );
      return;
    }
    setState(
      () => hours.add({
        'day': selectedDay,
        'opensAt': formatted(start),
        'closesAt': formatted(end),
      }),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Disponibilidad del local')),
    body: error != null && store == null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            ),
          )
        : store == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('Recibir pedidos'),
                subtitle: Text(
                  store!['open'] == true ? 'Local abierto' : 'Local cerrado',
                ),
                value: store!['acceptingOrders'] == true,
                onChanged: busy ? null : _switch,
              ),
              const Divider(),
              const ListTile(
                title: Text('Horarios'),
                subtitle: Text(
                  'Sin horarios configurados, el interruptor controla la disponibilidad.',
                ),
              ),
              for (var i = 0; i < hours.length; i++)
                ListTile(
                  title: Text(days[(hours[i]['day'] as int) - 1]),
                  subtitle: Text(
                    '${hours[i]['opensAt']} - ${hours[i]['closesAt']}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Eliminar horario',
                    onPressed: busy
                        ? null
                        : () => setState(() => hours.removeAt(i)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              TextButton.icon(
                onPressed: busy ? null : _addHours,
                icon: const Icon(Icons.add),
                label: const Text('Agregar horario'),
              ),
              FilledButton(
                onPressed: busy ? null : _save,
                child: const Text('Guardar horarios'),
              ),
              if (busy) const LinearProgressIndicator(),
            ],
          ),
  );
}
