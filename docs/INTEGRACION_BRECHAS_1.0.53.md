# Integracion movil 1.0.53

Base verificada el 23-11-2026: backend `GessofDev/Flashdrop@78d16ce` y
app `javier-sudo/flash-drop-delivery-app@f929d6f`.
Esta entrega incorpora los cambios de los PR moviles #13 y #15 sin modificar el backend.

## Alcance

| Brecha | Integracion movil |
| --- | --- |
| F1 | Rechazar en Nuevo pedido, Preparando o Listo para retiro; el servidor valida propiedad y estado. |
| F2 | Cancelar pedidos pendientes de pago o nuevos; el servidor decide si siguen siendo cancelables. |
| F3 | Abierto/cerrado, horarios, bloqueo de compra y revalidacion al confirmar. |
| F4 | Recuperacion desde login, cooldown y enlace de restablecimiento del PR #13. |
| F5 | Eliminacion con contrasena y confirmacion; bloqueos por procesos activos y cierre de sesion al aceptar. |
| F6 | Excluido: administracion corresponde al panel web. |
| F7 | Pago pendiente separado del pedido confirmado; paid orders visibles en Preparando; motivo de cancelacion del servidor. |
| F8 | Cotizacion del servidor, tarjeta en linea, idempotencia, estado/reintento de pago y pasarela fake claramente identificada. |
| F9 | Se conservan avisos locales y servicio foreground del PR #14; no es push FCM. |
| F10 | Editar nombre/apellido/telefono; subir, consultar y quitar foto autenticada JPEG/PNG de hasta 2 MB. Correo no editable. |
| F11 | Pin y comuna del cliente, catalogo por cobertura, configuracion de ubicacion/radio del comercio y revalidacion del carrito. |
| F12 | Crear/editar/desactivar productos, categoria, disponibilidad, imagen y dimension 1-10. Incluye resumen de ventas. |
| F13 | Envio GPS voluntario desde la pantalla de ruta activa en primer plano. Lectura del cliente preparada solo cuando exista un routeId real. |
| F14 | Calificar pedidos entregados, pendientes por actor e historial/publicas del comercio. No incluye propinas, cupones ni puntos. |
| F15/F16 | Sin contrato disponible para multi-comercio por cuenta o cambio de correo; no se simulan. |
| F17 | Soltar antes del retiro y anular despues con motivo obligatorio, ID numerico o UUID y validacion de propiedad en el servidor. |
| F18 | Al recibir 423 se recargan las rutas para retirar el pedido cancelado automaticamente. |

Se preservan las fotos remotas/relativas del catalogo y el orden/filtros de delivery:
recientes, antiguos, monto y distancia. Los valores desconocidos no se inventan.
Los reclamos de suscripcion/envio gratis de muestra se ocultan fuera del modo demo;
el envio se cotiza, no se anuncia una tarifa fija como precio definitivo.

## Limites y requisitos del servidor

- Integrado en codigo no significa desplegado. Verificar migraciones, correo SMTP,
  bucket de fotos y configuracion de pasarela en el entorno elegido.
- F8 usa la pasarela simulada disponible en main. Aprobar/rechazar pago de prueba
  no cobra dinero real. El cliente no maneja credenciales bancarias ni webhooks.
- F11 requiere pin y radio reales de cada comercio. Sin ellos no se inventa cobertura.
  Consulta publica del 23-11-2026 al gateway configurado: 3 comercios, ninguno
  con latitude/longitude ni deliveryRadiusKm configurados. Antes de probar una
  compra, entrar como comercio, abrir Zona de despacho y guardar su pin y radio.
- F13: `OrderDetailResponse.RouteDto` no expone el identificador de ruta que exige
  `GET /api/delivery/routes/{routeId}/location`. Backend debe entregarlo para que
  el seguimiento del cliente funcione extremo a extremo. Nunca se usa orderId como routeId.
  Los puntos con mas de 30 segundos o coordenadas invalidas se descartan.
- GPS no funciona como tracking continuo en segundo plano. Se detiene al salir
  de la pantalla, enviar la app a segundo plano o terminar la ruta.
- F9 depende de permisos y restricciones de Android. No funciona despues de
  forzar detencion; no sustituye una implementacion de push real.
- APK de prueba firmado con la clave debug existente del proyecto; no es un
  paquete aprobado para distribucion en Play Store.

## Verificacion

Ejecutar `flutter analyze` y `flutter test` en esta rama.
Verificacion final: analisis sin incidencias y 159 pruebas aprobadas.
Las pruebas nuevas cubren contratos HTTP con clientes simulados, multipart y
autorizacion de fotos, importes invalidos, idempotencia, cambio de total,
fallos de cotizacion, pago simulado, reintentos, calificaciones, formularios en
360 px, ubicaciones vencidas y recarga de rutas despues de un 423.

Pruebas manuales pendientes en telefono y servidor de prueba:

1. Configurar pin/radio/horarios como comercio; confirmar catalogo dentro/fuera y local cerrado.
2. Crear pedido con tarjeta simulada; aprobar/rechazar/reintentar; comprobar Preparando y rechazo antes del retiro.
3. Recuperar contrasena por correo y comprobar enlace/caducidad sin revelar cuentas existentes.
4. Editar perfil, cambiar/eliminar foto y revisar permisos, errores 413/429/503.
5. Soltar/anular un pedido propio; rechazar operaciones sobre pedidos ajenos o terminales.
6. Agotar los dos grupos de tres PIN incorrectos solo en un pedido de prueba; verificar cancelacion y cierre de ruta.
7. Entregar un pedido y calificar una sola vez por destino permitido.
8. Probar notificaciones con Android bloqueado, cambio de rol y cierre de sesion.
9. Probar eliminacion solo con una cuenta desechable, primero con y despues sin pedidos activos.
