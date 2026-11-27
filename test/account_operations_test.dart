import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app_delivery_gessof/src/models/response_api.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/account/delete_account_page.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';

class AccountFake extends AppProvider {
  int deletions = 0;
  @override
  Future<ResponseApi> deleteAccount(String password) async {
    deletions++;
    return ResponseApi(
      success: false,
      statusCode: 409,
      error: 'ACCOUNT_HAS_ACTIVE_PROCESSES',
    );
  }

}

void main() {
  testWidgets(
    'eliminar requiere contraseña y confirmación y respeta pedidos activos',
    (tester) async {
      final api = AccountFake();
      await tester.pumpWidget(
        MaterialApp(home: DeleteAccountPage(provider: api)),
      );
      await tester.tap(find.byType(FilledButton).first);
      await tester.pump();
      expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
      expect(api.deletions, 0);
      await tester.enterText(find.byType(TextField), 'ejemplo');
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      expect(api.deletions, 0);
      await tester.tap(find.text('Sí, eliminar'));
      await tester.pumpAndSettle();
      expect(api.deletions, 1);
      expect(find.textContaining('Tienes pedidos en curso'), findsOneWidget);
    },
  );

}
