# Pago automatico de prueba - 1.0.56

Este APK confirma automaticamente el pago simulado despues de crear un pedido.
No cobra dinero ni declara aprobado un pago solo cambiando la pantalla.

1. Consulta `GET /api/orders/{id}/payments` con la sesion del cliente.
2. Solo si el pedido y pago estan pendientes, no vencidos y la URL es
   `fake://flashdrop-pay/{transaccion}`, llama
   `POST /api/payments/fake/{transaccion}/resolve` con `outcome: APPROVED`.
3. Vuelve a consultar el servidor. Abre el seguimiento solo con pago APROBADO
   y pedido activo. La version anterior del backend lo activa en Preparando;
   la correccion de aceptacion manual lo deja en Nuevo pedido para el comercio.
4. Ante un fallo conserva el mismo pedido. Actualizar/reintentar consulta primero
   el estado real para no repetir una aprobacion que ya se haya confirmado.

Para un pedido anterior pendiente: Mis pedidos > abrir pedido > Continuar pedido
de prueba. Esto no reabre pedidos cancelados ni pagos vencidos.

## Compilacion QA

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://76-13-168-23.sslip.io --dart-define=USE_DEMO_MODE=false --dart-define=AUTO_APPROVE_TEST_PAYMENTS=true
```

La opcion `AUTO_APPROVE_TEST_PAYMENTS` es false por defecto. Omitirla para una
compilacion normal y nunca publicar este APK QA como una version de cobros reales.
Si el servidor usa una pasarela real, este modo no la aprueba ni la abre.
El servidor debe tener habilitada su pasarela fake y el endpoint simulador.

## Verificacion

```powershell
flutter analyze --no-pub
flutter test --no-pub --dart-define=AUTO_APPROVE_TEST_PAYMENTS=true
flutter test --no-pub test/automatic_test_payment_test.dart test/brechas_screens_test.dart
```

Las pruebas usan servicios simulados: URL y vencimiento, aprobacion unica,
fallos de red, reintento del mismo pedido, confirmacion del estado real,
rechazo/cancelacion y checkout automatico con el flag QA.
El 26-11-2026 se comprobo en un Samsung S23 con APK QA 1.0.57: creacion,
confirmacion del pago simulado, recepcion en comercio como Nuevo pedido y
entrega completa con PIN. No se realizaron cobros reales. Ver
`VALIDACION_1.0.57.md` para las limitaciones de esa ejecucion.
