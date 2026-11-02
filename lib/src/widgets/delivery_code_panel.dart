import 'package:flutter/material.dart';

class DeliveryCodePanel extends StatelessWidget {
  const DeliveryCodePanel({super.key, required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final value = order['deliveryCode'] ?? order['delivery_code'];
    final pin = value is String ? value.trim() : '';
    final available = RegExp(r'^\d{6}$').hasMatch(pin);
    final mode = '${order['receptionMode'] ?? order['reception_mode'] ?? ''}'
        .trim()
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: available ? const Color(0xFFEEF3FF) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Código de entrega',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (available) ...[
            Text(
              pin,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text('Compártelo solo al recibir tu pedido.'),
          ] else
            Text(
              mode == 'NORMAL'
                  ? 'Este pedido anterior no tiene código de entrega.'
                  : 'Código no disponible. Actualiza el pedido con la cuenta que lo creó.',
            ),
        ],
      ),
    );
  }
}
