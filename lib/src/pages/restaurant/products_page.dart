import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/ui/app_image.dart';

class RestaurantProductsPage extends StatefulWidget {
  const RestaurantProductsPage({super.key, required this.provider});
  final AppProvider provider;
  @override
  State<RestaurantProductsPage> createState() => _RestaurantProductsPageState();
}

class _RestaurantProductsPageState extends State<RestaurantProductsPage> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> categories = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.provider.getMyProducts(),
        widget.provider.getCategories(),
      ]);
      if (mounted) {
        setState(() {
          products = values[0];
          categories = values[1];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudieron cargar los productos.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? product]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ProductEditor(
          provider: widget.provider,
          categories: categories,
          product: product,
        ),
      ),
    );
    if (saved == true && mounted) await load();
  }

  Future<void> deactivateProduct(Map<String, dynamic> product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar producto'),
        content: Text('¿Dejar de ofrecer ${product['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => loading = true);
    try {
      await widget.provider.deactivateMyProduct(product['id'] as Object);
      if (mounted) await load();
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error =
              'No se pudo confirmar la desactivación. Actualiza antes de reintentar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis productos'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: loading || error != null ? null : () => edit(),
      icon: const Icon(Icons.add),
      label: const Text('Producto'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                TextButton(onPressed: load, child: const Text('Reintentar')),
              ],
            ),
          )
        : products.isEmpty
        ? const Center(child: Text('Aún no tienes productos.'))
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: products.length,
            itemBuilder: (context, i) {
              final p = products[i];
              return ListTile(
                leading: SizedBox(
                  width: 52,
                  height: 52,
                  child: AppImage(p['image']?.toString()),
                ),
                title: Text('${p['name'] ?? ''}'),
                subtitle: Text(
                  '${clp(toDouble(p['price']))} · ${p['available'] == true ? 'Disponible' : 'No disponible'}',
                ),
                onTap: () => edit(p),
                trailing: p['available'] == true
                    ? IconButton(
                        tooltip: 'Desactivar',
                        onPressed: () => deactivateProduct(p),
                        icon: const Icon(Icons.visibility_off_outlined),
                      )
                    : null,
              );
            },
          ),
  );
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({
    required this.provider,
    required this.categories,
    this.product,
  });
  final AppProvider provider;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? product;
  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: '${widget.product?['name'] ?? ''}',
  );
  late final description = TextEditingController(
    text: '${widget.product?['description'] ?? ''}',
  );
  late final price = TextEditingController(
    text: widget.product == null ? '' : '${widget.product!['price']}',
  );
  int? categoryId;
  String? imageKey;
  XFile? newImage;
  bool available = true;
  int dimension = 1;
  bool busy = false;
  String? error;
  bool legacyImage = false;

  @override
  void initState() {
    super.initState();
    categoryId = toInt(widget.product?['categoryId']);
    available = widget.product?['available'] != false;
    dimension = (toInt(widget.product?['dimension']) ?? 1).clamp(1, 10);
    final image = '${widget.product?['image'] ?? ''}';
    final match = RegExp(
      r'(products/\d{4}/\d{2}/[a-fA-F0-9-]{36}\.(?:jpg|jpeg|png|webp))$',
    ).firstMatch(image);
    imageKey = match?.group(1);
    legacyImage = image.isNotEmpty && imageKey == null;
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!(form.currentState?.validate() ?? false) ||
        categoryId == null ||
        busy) {
      if (categoryId == null) {
        setState(() => error = 'Selecciona una categoría.');
      }
      return;
    }
    if (legacyImage && newImage == null) {
      setState(
        () => error =
            'Selecciona una imagen nueva para conservar una imagen válida.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (newImage != null) {
        imageKey = await widget.provider.uploadMyProductImage(newImage!);
        newImage = null;
        legacyImage = false;
      }
      await widget.provider.saveMyProduct({
        'name': name.text.trim(),
        'description': description.text.trim(),
        'price': double.parse(price.text.trim().replaceAll(',', '.')),
        'categoryId': categoryId,
        'available': available,
        'dimension': dimension,
        if (imageKey != null) 'image': imageKey,
      }, id: widget.product?['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'No se pudo confirmar el guardado. Actualiza la lista antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.product == null ? 'Nuevo producto' : 'Editar producto',
      ),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: name,
            maxLength: 100,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Ingresa un nombre.' : null,
          ),
          TextFormField(
            controller: description,
            maxLength: 255,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          TextFormField(
            controller: price,
            enabled: !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Precio'),
            validator: (v) {
              final value = double.tryParse(
                (v ?? '').trim().replaceAll(',', '.'),
              );
              return value == null || !value.isFinite || value <= 0
                  ? 'Ingresa un precio mayor que cero.'
                  : null;
            },
          ),
          DropdownButtonFormField<int>(
            value: widget.categories.any((c) => toInt(c['id']) == categoryId)
                ? categoryId
                : null,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              for (final c in widget.categories)
                if (toInt(c['id']) != null)
                  DropdownMenuItem(
                    value: toInt(c['id']),
                    child: Text('${c['name']}'),
                  ),
            ],
            onChanged: busy ? null : (v) => setState(() => categoryId = v),
          ),
          SwitchListTile(
            title: const Text('Disponible'),
            value: available,
            onChanged: busy ? null : (v) => setState(() => available = v),
          ),
          DropdownButtonFormField<int>(
            value: dimension,
            decoration: const InputDecoration(
              labelText: 'Dimension de transporte',
            ),
            items: [
              for (var i = 1; i <= 10; i++)
                DropdownMenuItem(value: i, child: Text('$i')),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() => dimension = v ?? dimension),
          ),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    try {
                      final file = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                      );
                      if (file != null && mounted) {
                        setState(() {
                          newImage = file;
                          error = null;
                        });
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(() => error = 'No se pudo abrir la galería.');
                      }
                    }
                  },
            icon: const Icon(Icons.photo_outlined),
            label: Text(
              newImage == null ? 'Elegir imagen' : 'Imagen seleccionada',
            ),
          ),
          if (legacyImage && newImage == null)
            const Text(
              'La imagen actual necesita ser reemplazada para guardar cambios.',
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Guardando...' : 'Guardar producto'),
          ),
        ],
      ),
    ),
  );
}
