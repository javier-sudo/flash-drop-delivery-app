# Flash Drop: brechas en validaciones, errores y caminos de falla

Revisión del código de la app Flutter (zip `flash-drop-delivery-app-main`), con el
rediseño ya aplicado. Los microservicios (Auth, Catalog, Orders, Delivery) no
vienen en el zip: lo que se lista del lado servidor es lo que la app **asume**
que el backend hace y hay que confirmar allá.

Prioridad: **P0** rompe un flujo o expone datos · **P1** el usuario queda sin
salida o ve información falsa · **P2** calidad y robustez.

---

## 1. Fallas confirmadas en el código

| # | Prio | Dónde | Problema | Qué pasa |
|---|---|---|---|---|
| 1 | P0 | `cart_page.dart` `_placeOrder` | `createOrder` no está en `try/catch`. | Si el Gateway no responde (túnel caído, sin red) el botón queda en "cargando" para siempre y la excepción no se maneja. |
| 2 | P0 | `app_provider.dart`, `users_provider.dart` | Ninguna llamada HTTP tiene `timeout`. | Con el túnel SSH caído las pantallas quedan con spinner indefinido. |
| 3 | P0 | `login_controller.dart` | El formulario viene precargado con `demo@flashdrop.cl` / `123456` **también fuera del modo demo**. | Credencial en el código y en producción. Precargar solo si `Environment.useDemoMode`. |
| 4 | P0 | `login_controller.dart`, `app_provider.dart` | No se maneja `401` ni se usa el `refreshToken`. | Al expirar el JWT todo falla con "Error HTTP 401" genérico; el usuario no vuelve al login. |
| 5 | P0 | `home_controller.dart` `signOut` | Solo borra `user` y `token`. | Quedan el carrito, la dirección, `selected_role`, la ruta activa del repartidor y los controllers GetX permanentes: el siguiente usuario del teléfono ve datos del anterior. |
| 6 | P1 | `login_controller.dart`, `register_controller.dart` | Se hace `.trim()` a la contraseña. | Una contraseña con espacio al inicio o al final se cambia sin avisar y luego no coincide. |
| 7 | P1 | Login y registro | El error muestra `'No se pudo conectar al backend: $e'`. | Expone detalles internos (URL, excepción) al usuario. Mostrar un mensaje fijo y registrar `e` en log. |
| 8 | P1 | `client_order_tracking_page.dart` `_geocode` | Si falla la geocodificación inventa coordenadas con un hash de la dirección. | El mapa muestra una ubicación falsa como si fuera real. Ocultar el mapa o marcar "ubicación aproximada". |
| 9 | P1 | `main.dart` | Las rutas no tienen guardas por sesión ni por rol. | En web cualquiera entra a `#/restaurant/orders/list` escribiendo la URL. Falta `GetMiddleware` (sin sesión → login; sin rol → selector). El backend igual debe validar el rol en cada endpoint. |
| 10 | P2 | `client_order_tracking_page.dart` | `Get.arguments` nulo deja `_orderId = ''`. | Llama a `/api/orders/` y muestra error genérico en vez de "pedido no encontrado". |

## 2. Validaciones que faltan

**Registro**
- RUT: no se valida formato ni dígito verificador (módulo 11), y es opcional sin regla clara.
- Teléfono: solo se revisa que no esté vacío; falta formato `+56 9 XXXX XXXX`.
- Contraseña: mínimo 6 caracteres sin más reglas. Sugerido: 8+ con letras y números.
- Nombre y apellido: sin largo máximo ni caracteres permitidos.
- La foto se elige pero **no se envía** (Auth no tiene endpoint) y no se avisa al usuario.
- Los errores salen en snackbars uno por uno; conviene mostrarlos bajo cada campo (`TextFormField.validator`).

**Checkout**
- Dirección: solo se pide `length >= 6`. Falta exigir número y comuna, o tomarla del selector con coordenadas.
- Total y envío (`deliveryFee = 2500`) se calculan en el cliente. **El servidor debe recalcular** precio, envío y total y rechazar montos manipulados.
- No se verifica que el local esté abierto ni que el producto siga disponible antes de confirmar.
- Sin cantidad máxima por producto ni monto mínimo de pedido.
- Sin idempotencia: un doble envío por red lenta puede crear dos pedidos. Enviar una `Idempotency-Key` por pedido.

**Estados del pedido**
- Los estados viajan como texto libre (`'Preparando'`, `'Entregado'`) y se comparan con `contains`. Falta un enum compartido con el backend y que el servidor valide las transiciones permitidas.

## 3. Caminos de falla sin cubrir (funcionalidad)

| Rol | Falta | Por qué importa |
|---|---|---|
| Cliente | Cancelar un pedido mientras está en "Nuevo pedido". | Hoy no hay forma de arrepentirse. |
| Restaurante | **Rechazar** un pedido con motivo (sin stock, cerrado). | Solo existe "Aceptar"; un pedido imposible queda colgado. |
| Restaurante | Marcar un producto como agotado o el local como cerrado. | Evita pedidos que no se pueden cumplir. |
| Repartidor | Reportar "**No entregado**" (cliente ausente, dirección errónea) o incidencia. | Solo existe "Entregado"; la ruta no se puede cerrar honestamente. |
| Repartidor | Ubicación real por GPS. | El marcador "Tu moto" no usa el GPS: `geolocator` está en `pubspec.yaml` pero no se usa. |
| Todos | Recuperar contraseña y editar perfil. | No hay pantallas ni endpoints. |
| Todos | Aviso de sin conexión y reintento. | Hoy solo aparecen errores genéricos. |
| Todos | Notificaciones push de cambio de estado. | Se depende de *polling* cada 20–30 s, sin *backoff*. |
| Cliente | Pago real (tarjeta o transferencia). | Solo hay método declarado; no se cobra. |

## 4. Camino web (Flutter Web)

- `GATEWAY_INTEGRATION.md` ya lo anota: contra FloCI el preflight CORS pasa, pero la
  petición real a Catalog con origen navegador recibe **403**. Hay que corregirlo en
  el Gateway antes de publicar la versión web.
- En web el token vive en `localStorage` (GetStorage). Para producción: cookie
  `HttpOnly` o un token de vida corta con renovación.
- Las guardas de rutas del punto 9 son más urgentes en web, porque las URLs se escriben a mano.
- `android:usesCleartextTraffic="true"`: sirve para el túnel local, pero en producción el Gateway debe ir por HTTPS y esa bandera debe quitarse.

## 5. Seguridad de cliente

- `accessToken` y `refreshToken` se guardan en GetStorage dentro del mapa `user`
  (texto plano). Usar `flutter_secure_storage` en móvil.
- Sin *logging* ni reporte de errores (Sentry o Crashlytics): las fallas en terreno no se ven.

## 6. Pruebas que faltan

- No hay pruebas contra el Gateway real: todo lo verificado corre en `USE_DEMO_MODE`.
- Faltan pruebas de contrato (formato de respuestas de Auth, Orders y Delivery) y de
  los caminos de error: timeout, 401, 403, 409 (pedido ya tomado) y 500.

---

## Orden sugerido

1. **Sprint corto (P0):** puntos 1–5. Son cambios acotados en la app, se pueden probar en modo demo y no dependen del backend.
2. **P1 de app:** puntos 6–9 y validaciones de registro y checkout.
3. **Con backend:** rechazar y cancelar pedidos, "No entregado", recálculo de montos en servidor, idempotencia, enum de estados, CORS del Gateway.
4. **Producto:** GPS real, push, recuperar contraseña, pagos.
