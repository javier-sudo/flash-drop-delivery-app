# Paridad funcional con el repositorio

Comparación entre esta versión rediseñada y `javier-sudo/flash-drop-delivery-app`
(revisado el 2026-11-02).

## Punto de partida

- El zip que se rediseñó corresponde exactamente al commit `165f695` del repo
  (15-10-2026, merge del PR 8). En `lib/` no hay ninguna diferencia.
- `main` va 6 commits adelante, de `68c0146` a `0535cde` (02-11-2026), y está en
  la versión 1.0.42 (el zip, en la 1.0.10). Son unas 2.400 líneas en 30 archivos.

## 1. Funciones del zip: se conservan todas

| Área | Zip (`165f695`) | Esta versión |
|---|---|---|
| Rutas | 9 rutas | Las mismas 9 rutas |
| `AppProvider` / `UsersProvider` | 11 métodos | Los mismos métodos y endpoints |
| Login, registro con foto y cierre de sesión | Sí | Sí |
| Catálogo, búsqueda, carrito y checkout (Efectivo, Tarjeta, Transferencia; distancia y tiempo estimado) | Sí | Sí |
| Direcciones (mapa, geocodificación inversa, guardadas) | Sí | Sí |
| Pedidos del cliente y seguimiento con mapa | Sí | Sí |
| Restaurante: lista, detalle y cambio de estado | Sí | Sí, más acciones rápidas |
| Repartidor: disponibles, tomar hasta 3, ruta en mapa, entregar, abrir navegación externa | Sí | Sí |

Lo que se agregó encima: diseño nuevo, carrito con varios productos, detalle de
restaurante, historial y switch "Disponible" del repartidor, modo demo
(`USE_DEMO_MODE`) e ilustraciones propias.

## 2. Lo que traía `main`: portado (2026-11-02)

Las 14 brechas detectadas se portaron manteniendo el diseño nuevo y el modo demo.

| # | Función de `main` | Dónde quedó |
|---|---|---|
| 1 | PIN de entrega (`SEGURO`, retiro y entrega con 409/422/423, intentos y código renovado) | `cart_page.dart` (aviso y `receptionMode`), `delivery_code_panel.dart`, `delivery_orders_list_page.dart` (`_markPickedUp`, `_markDelivered`, `deliveryErrorMessage`), `AppProvider.deliverOrder`, `DemoBackend.deliver` |
| 2 | `getOrders(view: client \| restaurant)` | `AppProvider.getOrders` |
| 3 | Sesión segura con refresh y restauración | `services/session_manager.dart`, `main.dart` |
| 4 | Sin credenciales precargadas | Login: solo en modo demo |
| 5 | Timeout de 15 s y banner sin conexión | `AppProvider._send`, `connection_service.dart`, `connection_banner.dart` |
| 6 | Notificaciones locales y Workmanager | `local_notifications_service.dart`, `background_order_sync_service.dart` (no corre en demo) |
| 7 | Categorías desde `/catalog/categories` | `AppProvider.getProducts` |
| 8 | Seguimiento en 5 pasos con mensajes | `utils/order_status.dart` (`OrderStage`) |
| 9 | `RegisteredAddressResolver` | Carrito, direcciones, seguimiento y repartidor |
| 10 | Ubicación real del repartidor y refresco cada 15 s | `delivery_orders_list_page.dart` (`_refreshDriverLocation`) |
| 11 | Ruta por calles (OSRM) y avisos del mapa | `widgets/map_tracking_osm.dart` (`roadRoute`) |
| 12 | Filtros de restaurante y cliente, orden por fecha | `restaurant_orders_list_page.dart`, `client_orders_list_widget.dart` |
| 13 | Android: `POST_NOTIFICATIONS`, `network_security_config`, desugaring, versión 1.0.42 | `android/app/...`, `pubspec.yaml` |
| 14 | Test del panel de código | `test/delivery_code_panel_test.dart` |

Diferencias deliberadas con `main`:

- `API_BASE_URL` sigue por `--dart-define` (sin IP por defecto en el código).
- Se conservan de `main` el `applicationId` (`com.javier.flashdrop.floci`), el
  nombre "Flash Drop FloCI", `scripts/run-floci.ps1` y la presentación sin
  credenciales demo.
- `network_security_config.xml` permite HTTP solo a `10.0.2.2`, `localhost`,
  `127.0.0.1` y al backend de pruebas `76-13-168-23.sslip.io`.
- En demo la moto se dibuja en el local cuando no hay GPS (web).

Pruebas: `flutter analyze` sin observaciones y 43 tests en verde
(`roles_flow_test.dart` cubre retiro, PIN errado y entrega;
`repo_parity_test.dart` cubre etapas, sesión, filtros y OSRM).

<details>
<summary>Brechas originales (antes del port)</summary>


| # | Función en `main` | Aquí | Impacto |
|---|---|---|---|
| 1 | **PIN de entrega.** El pedido se crea con `receptionMode: 'SEGURO'` y el cliente ve un código de 6 dígitos en el seguimiento (`DeliveryCodePanel`). El repartidor primero marca "Confirmar retiro" (estado `Retirado`) y después "Confirmar entrega" con el PIN (`POST /api/orders/{id}/deliver`). Maneja los códigos 409, 422 y 423, los intentos restantes y el código renovado. | No existe. El repartidor entrega con `PUT /api/delivery/routes/{id}/status`, un endpoint que `main` ya no usa. | **Crítico.** Si el backend se actualizó junto con el repo, el repartidor no puede cerrar entregas. |
| 2 | `getOrders(view: client \| restaurant)` | Pide `/api/orders` sin `view` | **Alto.** Puede mezclar pedidos entre roles. |
| 3 | **Sesión segura.** Tokens en `flutter_secure_storage`, renovación automática (`/auth/refresh`), restauración de sesión al abrir la app y migración de la sesión antigua. Cerrar sesión borra el rol elegido. | Token en `GetStorage` y sin refresh: cuando el token vence, todo empieza a fallar. | **Alto** |
| 4 | Login y registro sin credenciales precargadas ni modo demo | Precarga `demo@flashdrop.cl` / `123456` | **Alto** en producción |
| 5 | Timeout de 15 s en todas las llamadas, detección de "sin conexión" y banner "Sin conexión. Reintentando..." que se pausa en segundo plano | Sin timeouts | Medio |
| 6 | Notificaciones locales (cambio de estado, nuevo pedido para el comercio) y sincronización en segundo plano cada 15 min (Workmanager, solo Android) | No existe | Medio |
| 7 | Categorías reales desde `/catalog/categories` | Muestra `categoryName` o "Otros" | Medio |
| 8 | Seguimiento con 5 pasos (se agrega "Listo" entre Preparando y En camino) y mensajes por estado | 4 pasos; "Listo para retiro" aparece como Preparando | Medio |
| 9 | Geocodificación real validada dentro de Chile y con caché (`RegisteredAddressResolver`) | El repartidor cae en coordenadas falsas derivadas del texto de la dirección | Medio |
| 10 | Ubicación real del repartidor (geolocator) y refresco cada 15 s | Sin ubicación real; refresco cada 30 s, solo mientras elige pedidos | Medio |
| 11 | Ruta por calles (OSRM) en el seguimiento, ubicación actual y aviso "No pudimos ubicar..." | Línea recta | Bajo |
| 12 | Filtros del restaurante: Todos, Nuevos, Preparando, Listos, En ruta y Entregados. Pedidos del cliente: Todos, En curso y Entregados, ordenados por fecha | Nuevos / En proceso / Entregados; En curso / Historial | Bajo (es sobre todo diseño) |
| 13 | Android: permiso `POST_NOTIFICATIONS`, `network_security_config` (cleartext solo a hosts definidos) y versión 1.0.42 | Cleartext abierto, versión 1.0.10 | Medio al publicar |
| 14 | Test `delivery_code_panel_test.dart` | No existe | — |


</details>

## Notas para portar

- Conviene portar la lógica (servicios, providers y modelos) casi tal cual y
  adaptar solo la interfaz al diseño nuevo.
- `main` puso como URL por defecto `http://76-13-168-23.sslip.io`. Es mejor
  mantener `API_BASE_URL` por `--dart-define`, sin una IP por defecto en el código.
- Si se porta el PIN, el modo demo también tiene que simularlo (retiro, PIN,
  intentos), o las presentaciones van a quedar cojas.
- Los puntos 3, 4 y 5 cierran los P0 2, 3, 4 y 5 de
  `docs/brechas-validaciones-y-errores.md`.
