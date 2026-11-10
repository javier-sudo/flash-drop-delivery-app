import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/forgot_password/forgot_password_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/login/login_page.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';

class ForgotPasswordPage extends StatelessWidget {
  ForgotPasswordPage({super.key});

  final ForgotPasswordController con = Get.put(ForgotPasswordController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.34,
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
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Volver',
                    onPressed: con.backToLogin,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(height: 8),
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
                  child: Obx(
                    () => con.sentTo.value == null
                        ? _RequestForm(con: con)
                        : _SentNotice(con: con),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestForm extends StatelessWidget {
  final ForgotPasswordController con;
  const _RequestForm({required this.con});

  @override
  Widget build(BuildContext context) => Obx(() => _build(context));

  Widget _build(BuildContext context) {
    final loading = con.isSending.value;
    final error = con.errorText.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recuperar contraseña',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Escribe el correo de tu cuenta y te enviaremos un enlace para '
          'crear una contraseña nueva.',
          style: TextStyle(color: AppColors.muted, height: 1.35),
        ),
        const SizedBox(height: 22),
        TextField(
          key: const Key('forgot-email'),
          controller: con.emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.send,
          maxLength: ForgotPasswordController.maxEmailLength,
          enabled: !loading,
          onSubmitted: (_) => con.send(),
          decoration: InputDecoration(
            hintText: 'Correo electrónico',
            prefixIcon: const Icon(Icons.email_outlined),
            counterText: '',
            errorText: error,
            errorMaxLines: 3,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: loading ? null : con.send,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar enlace'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: con.backToLogin,
            child: const Text('Volver a iniciar sesión'),
          ),
        ),
      ],
    );
  }
}

class _SentNotice extends StatelessWidget {
  final ForgotPasswordController con;
  const _SentNotice({required this.con});

  @override
  Widget build(BuildContext context) => Obx(() => _build(context));

  Widget _build(BuildContext context) {
    final seconds = con.cooldown.value;
    final sending = con.isSending.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.primaryDark,
            size: 30,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Revisa tu correo',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Si ${con.sentTo.value} está registrado, te enviamos un enlace '
          'para crear una contraseña nueva.',
          style: const TextStyle(height: 1.35),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 20, color: AppColors.muted),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El enlace se abre en el navegador y vence en 30 minutos. '
                  'Si no lo ves, revisa la carpeta de spam. Después vuelve '
                  'aquí e inicia sesión con tu contraseña nueva.',
                  style: TextStyle(color: AppColors.muted, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        if (con.errorText.value != null) ...[
          const SizedBox(height: 12),
          Text(
            con.errorText.value!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: con.backToLogin,
            child: const Text('Volver a iniciar sesión'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: TextButton(
                onPressed: seconds > 0 || sending ? null : con.send,
                child: Text(
                  seconds > 0 ? 'Reenviar en ${seconds}s' : 'Reenviar enlace',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: sending ? null : con.useAnotherEmail,
                child: const Text(
                  'Usar otro correo',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
