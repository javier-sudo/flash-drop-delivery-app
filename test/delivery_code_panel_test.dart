import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_delivery_gessof/src/widgets/delivery_code_panel.dart';

void main() {
  testWidgets('shows the six-digit deliveryCode including leading zero', (
    tester,
  ) async {
    final response =
        jsonDecode(
              '{"success":true,"data":{"receptionMode":"SEGURO","deliveryCode":"012345"}}',
            )
            as Map<String, dynamic>;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeliveryCodePanel(
            order: Map<String, dynamic>.from(response['data']),
          ),
        ),
      ),
    );
    expect(find.text('012345'), findsOneWidget);
  });

  testWidgets('shows an explanation when the server omits the code', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DeliveryCodePanel(order: {'receptionMode': 'SEGURO'}),
        ),
      ),
    );
    expect(find.textContaining('Código no disponible'), findsOneWidget);
  });
}
