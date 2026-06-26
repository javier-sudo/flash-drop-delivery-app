import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/register/register_controller.dart';

const kYellowStart = Color(0xFFFFC107);
const kYellowEnd = Color(0xFFFFB300);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final RegisterController con = Get.put(RegisterController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear perfil demo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        children: [
          Center(child: _imageUser(context)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _Field(
                  controller: con.emailController,
                  hint: 'Correo electronico',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: con.rutController,
                  hint: 'RUT',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: con.nameController,
                  hint: 'Nombre',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: con.lastnameController,
                  hint: 'Apellido',
                  icon: Icons.person,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: con.phoneController,
                  hint: 'Telefono',
                  icon: Icons.phone_outlined,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: con.passwordController,
                  hint: 'Contrasena',
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: con.confirmPasswordController,
                  hint: 'Confirmar contrasena',
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 22),
                Obx(() {
                  final loading = con.isLoading.value;
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: loading ? null : () => con.register(context),
                      child: loading
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : const Text('Crear y entrar'),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageUser(BuildContext context) {
    return GestureDetector(
      onTap: () => con.showAlertDialog(context),
      child: GetBuilder<RegisterController>(
        builder: (c) {
          final ImageProvider image = c.imagenFile != null
              ? FileImage(c.imagenFile!)
              : const AssetImage('assets/img/usuario2.0.png');

          return CircleAvatar(
            radius: 58,
            backgroundColor: const Color(0xFFFFECB3),
            backgroundImage: image,
          );
        },
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: kYellowEnd, width: 1.4),
        ),
      ),
    );
  }
}
