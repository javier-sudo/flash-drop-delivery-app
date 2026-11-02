import 'package:flutter/material.dart';

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
        color: available ? const Color(0xFF1E2025) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_outline, color: Color(0xFFFFB300)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Código de entrega',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: available ? Colors.white70 : const Color(0xFF8A5700),
                  ),
                ),
                const SizedBox(height: 4),
                if (available) ...[
                  // Espaciado amplio para dictarlo sin errores.
                  Text(
                    pin,
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 6,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFB300),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Text(
                    'Compártelo solo al recibir tu pedido.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ] else
                  Text(
                    mode == 'NORMAL'
                        ? 'Este pedido anterior no tiene código de entrega.'
                        : 'Código no disponible. Actualiza el pedido con la cuenta que lo creó.',
                    style: const TextStyle(color: Color(0xFF6A4300)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
