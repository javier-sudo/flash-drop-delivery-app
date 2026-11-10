import 'package:flutter/material.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/client_theme.dart';

/// Código de entrega (PIN de 6 dígitos) que el cliente comparte con el
/// repartidor al recibir el pedido. Lo entrega Orders en `deliveryCode` solo a
/// la cuenta que creó el pedido.
class DeliveryCodePanel extends StatelessWidget {
  const DeliveryCodePanel({super.key, required this.order});

  final Map<String, dynamic> order;

  static String? codeOf(Map<String, dynamic> order) {
    final value = order['deliveryCode'] ?? order['delivery_code'];
    final pin = value is String ? value.trim() : '';
    return RegExp(r'^\d{6}$').hasMatch(pin) ? pin : null;
  }

  @override
  Widget build(BuildContext context) {
    final pin = codeOf(order);
    final mode = '${order['receptionMode'] ?? order['reception_mode'] ?? ''}'
        .trim()
        .toUpperCase();
    final available = pin != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: available ? FD.navy : FD.soft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FD.yellow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.lock_outline, color: FD.navy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Código de entrega',
                  style: FD.text(
                    13.5,
                    weight: FontWeight.w800,
                    color: available ? const Color(0xFFDFE3EC) : FD.brown,
                  ),
                ),
                const SizedBox(height: 4),
                if (available) ...[
                  // Espaciado amplio para dictarlo sin errores.
                  Text(
                    pin,
                    style: const TextStyle(
                      fontFamily: FD.font,
                      fontSize: 30,
                      letterSpacing: 6,
                      fontWeight: FontWeight.w900,
                      color: FD.yellow,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Text(
                    'Compártelo solo al recibir tu pedido.',
                    style: TextStyle(
                      fontFamily: FD.font,
                      color: Color(0xFFDFE3EC),
                      fontSize: 12,
                    ),
                  ),
                ] else
                  Text(
                    mode == 'NORMAL'
                        ? 'Este pedido anterior no tiene código de entrega.'
                        : 'Código no disponible. Actualiza el pedido con la cuenta que lo creó.',
                    style: FD.text(13, color: FD.brown),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
