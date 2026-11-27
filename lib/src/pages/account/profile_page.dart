import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

class AccountProfilePage extends StatefulWidget {
  const AccountProfilePage({super.key, this.provider});
  final AppProvider? provider;
  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  late final _api =
      widget.provider ??
      (Get.isRegistered<AppProvider>()
          ? Get.find<AppProvider>()
          : AppProvider());
  Uint8List? _photo;
  String _email = '';
  bool _loading = true;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _persist(Map<String, dynamic> profile) async {
    if (!mounted) return;
    final previous = GetStorage().read('user');
    final safe =
        {
            if (previous is Map) ...Map<String, dynamic>.from(previous),
            ...profile,
          }
          ..remove('accessToken')
          ..remove('refreshToken')
          ..remove('token');
    await GetStorage().write('user', safe);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _api.getProfile();
      if (!mounted) return;
      _name.text = '${profile['name'] ?? ''}';
      _lastName.text = '${profile['lastName'] ?? profile['last_name'] ?? ''}';
      _phone.text = '${profile['phone'] ?? ''}';
      _email = '${profile['email'] ?? ''}';
      await _persist(profile);
      try {
        _photo = await _api.getProfilePhoto(
          version: Uri.tryParse(
            '${profile['photo'] ?? ''}',
          )?.queryParameters['v'],
        );
      } catch (_) {
        _error = 'No se pudo cargar la foto. Tus datos sí están disponibles.';
      }
    } catch (_) {
      _error = 'No se pudo cargar el perfil.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message.toString()
              : 'No se pudo guardar. Revisa la conexión o intenta más tarde.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_busy) return;
    try {
      final file = await ImagePicker().pickImage(source: source);
      if (file == null || !mounted) return;
      await _run(() async {
        final profile = await _api.uploadProfilePhoto(file);
        await _persist(profile);
        final photo = await _api.getProfilePhoto(
          version: Uri.tryParse(
            '${profile['photo'] ?? ''}',
          )?.queryParameters['v'],
        );
        if (mounted) setState(() => _photo = photo);
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo abrir la cámara o galería. Revisa sus permisos.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Editar mis datos')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: _photo == null
                        ? null
                        : MemoryImage(_photo!),
                    child: _photo == null
                        ? const Icon(Icons.person, size: 46)
                        : null,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Elegir foto',
                      onPressed: _busy
                          ? null
                          : () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                    IconButton(
                      tooltip: 'Tomar foto',
                      onPressed: _busy
                          ? null
                          : () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                    ),
                    IconButton(
                      tooltip: 'Quitar foto',
                      onPressed: _busy || _photo == null
                          ? null
                          : () => _run(() async {
                              await _api.deleteProfilePhoto();
                              final profile = await _api.getProfile();
                              await _persist(profile);
                              if (mounted) setState(() => _photo = null);
                            }),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                Text(_email, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Ingresa tu nombre' : null,
                ),
                TextFormField(
                  controller: _lastName,
                  enabled: !_busy,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Ingresa tu apellido' : null,
                ),
                TextFormField(
                  controller: _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  maxLength: 20,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  validator: (v) =>
                      !RegExp(r'^\+?[0-9]{8,15}$').hasMatch((v ?? '').trim())
                      ? 'Ingresa entre 8 y 15 dígitos'
                      : null,
                ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recargar'),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          if (_form.currentState!.validate()) {
                            _run(() async {
                              final profile = await _api.updateProfile(
                                name: _name.text.trim(),
                                lastName: _lastName.text.trim(),
                                phone: _phone.text.trim(),
                              );
                              await _persist(profile);
                            });
                          }
                        },
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
  );
}
