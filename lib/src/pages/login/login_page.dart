import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/login/login_controller.dart';

const kYellowStart = Color(0xFFFFC107);
const kYellowEnd = Color(0xFFFFB300);

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  final LoginController con = Get.put(LoginController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kYellowStart, kYellowEnd],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 32, 22, 24),
              children: [
                Center(
                  child: Image.asset(
                    'assets/img/logo_flash_drop.png',
                    width: 126,
                    height: 126,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Flash Drop',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'App multirol para clientes, restaurantes y repartidores.',
                      ),
                      const SizedBox(height: 22),
                      _DemoBadge(),
                      const SizedBox(height: 18),
                      _TextFieldBox(
                        controller: con.emailController,
                        hint: 'Correo electronico',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _TextFieldBox(
                        controller: con.passwordController,
                        hint: 'Contrasena',
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
                            onPressed: loading ? null : con.login,
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Iniciar sesion'),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Quieres crear un perfil?'),
                    TextButton(
                      onPressed: con.goToRegisterPage,
                      child: const Text('Registrate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFFFFA000), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Puedes usar admin@demo.cl / 123456 si cargaste database.sql.',
            ),
          ),
        ],
      ),
    );
  }
}

class _TextFieldBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _TextFieldBox({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
      ),
    );
  }
}
