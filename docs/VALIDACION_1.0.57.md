# Validacion de la app 1.0.57

## Version

- Flutter: `1.0.57+57`.
- Integracion de recuperacion de clave F4 y cobertura por radio F11.
- Operaciones de cuenta, foto y calificaciones, gestion del comercio y productos.
- Checkout cotizado y pago simulado, ordenamiento de pedidos, operaciones del
  repartidor, persistencia de direcciones y avisos por asignacion al comercio.
- F6 administrativo fuera del alcance movil.

La aprobacion automatica de pagos de prueba solo se activa al compilar con
`AUTO_APPROVE_TEST_PAYMENTS=true`; el valor por defecto sigue siendo false.
No usar ese APK QA como version de cobros reales.

## Prueba exploratoria del 26-11-2026

Celular Samsung S23, APK 1.0.57, conectado por ADB inalambrico y Mobilewright.
Se reutilizo un solo pedido QA, sin crear pedidos adicionales durante la
continuacion entre roles:

1. Cliente: inicio de sesion, direccion persistida, catalogo, carrito, cotizacion
   y confirmacion del pago simulado.
2. Comercio: Nuevo pedido -> Aceptar -> Preparando -> Listo para retiro.
3. Delivery: toma individual del pedido y recuperacion de ruta al volver a
   iniciar sesion.
4. Comercio: Repartidor Asignado, conservando Listo para retiro.
5. Delivery: confirmacion de retiro; cliente muestra Va en camino / Retirado.
6. PIN vacio: validacion local. PIN correcto: entrega aceptada y ruta cerrada.
7. Cliente y comercio: Entregado. Cliente sin PIN ni cancelacion al terminar.
8. Calificacion: estrellas y comentario disponibles; envio deshabilitado sin
   estrellas. No se publico una valoracion ficticia.

Pruebas Mobilewright externas al repositorio: 7 comprobaciones del cliente antes
de la entrega y 3 posteriores, aprobadas. No son una suite E2E desatendida de
todo el recorrido: los cambios entre roles se ejecutaron mediante CLI.

Las credenciales, tokens, PIN, direcciones personales y capturas privadas no se
incluyen en este repositorio. Tampoco se incluyen los APK generados.

## Verificacion previa a publicacion, 27-11-2026

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub --reporter expanded`: 201 pruebas aprobadas.
- `flutter test --no-pub --dart-define=AUTO_APPROVE_TEST_PAYMENTS=true
  test/automatic_test_payment_test.dart test/brechas_screens_test.dart
  --reporter expanded`: 19 pruebas aprobadas con el modo QA habilitado.

## Pendientes conocidos

- P2: historial de delivery sin identificacion del pedido/comercio y con monto
  cero. La API de rutas trae `orderId`, `code` vacio y no trae `total` ni
  `restaurantName`; la pantalla usa esos campos. Se requiere respaldo
  `FD-{orderId}`, enriquecimiento por APIs y representar monto ausente sin
  inventar un cero. Esta integracion no corrige ese defecto.
- P2: controles de icono sin etiquetas accesibles y selector de rol con nodos
  agrupados; revisar Semantics y contrastar con una compilacion debug.
- P3: el comercio etiqueta el pago simulado como Tarjeta.
- P3: el mensaje de PIN vacio permanece hasta confirmar aunque ya haya seis
  digitos en el campo.

No se validaron notificaciones simultaneas (se alternaron cuentas en un solo
celular), restricciones de bateria, GPS en movimiento, exactitud de distancias
y ETA, carreras concurrentes, PIN incorrecto/bloqueo, liberacion/reasignacion,
anulacion posterior al retiro, errores de red ni pagos reales.
El retiro envia el estado Retirado; no se probo una transicion independiente
al estado de backend En camino.
