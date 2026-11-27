# Flash Drop Delivery App

Aplicacion Flutter multirol para un prototipo de delivery tipo Uber Eats.

## Funcionalidades

- Cliente: catalogo, busqueda, carrito, direccion, pedido e historial con
  seguimiento en 5 pasos (Recibido, Preparando, Listo, En camino, Entregado),
  ruta por calles en el mapa y PIN de entrega de 6 digitos.
- Restaurante: pedidos del local filtrados por estado (Todos, Nuevos,
  Preparando, Listos, En ruta, Entregados), detalle y cambio de estado.
- Repartidor: toma pedidos disponibles, agrupa hasta 3 pedidos, ve ruta en mapa
  con su ubicacion real, confirma el retiro en el local y entrega con el PIN del
  cliente (3 intentos; al tercero el codigo se renueva).
- Sesion: tokens en almacenamiento seguro con renovacion automatica
  (`/auth/refresh`); al cerrar sesion se borran rol, direccion y ruta activa.
- Recuperar contrasena: "¿Olvidaste tu contraseña?" en el login abre
  `/forgot-password`, que pide el correo a `POST /auth/password/forgot`. Auth
  responde 202 exista o no el correo y envia un enlace que abre la pagina
  `/recuperar-clave` de la web (vence en 30 min). Reenvio cada 60 s; avisos
  para 429 (demasiadas solicitudes) y sin conexion. En modo demo se simula.
- Red: timeout de 15 s por llamada y banner "Sin conexion. Reintentando...".
- Notificaciones locales de cambios de estado y sincronizacion en segundo plano
  cada 15 min (solo Android).
- Backend conectado al API Gateway de FlashDrop. La URL se entrega al ejecutar o
  compilar mediante `API_BASE_URL`.

## Credenciales demo

Solo para el backend demo o de pruebas; la app ya no las precarga salvo en modo
demo. Todas usan la contrasena `123456`.

- Cliente: `cliente@demo.cl`
- Restaurante: `restaurante@demo.cl`
- Repartidor: `repartidor@demo.cl`
- Multirol: `admin@demo.cl`
- Restaurante Arauco Maipu: `araucomaipu@flashdrop.cl`

## Requisitos

- Flutter SDK instalado.
- Android Studio o un dispositivo Android conectado.

## Ejecutar en desarrollo

```powershell
flutter pub get
./scripts/run-floci.ps1 -Target android-emulator
```

El comando abre un tunel SSH hacia FloCI y ejecuta la app contra el Gateway.
Para Windows nativo usa `-Target windows`. Para otros detalles, ve
[GATEWAY_INTEGRATION.md](GATEWAY_INTEGRATION.md).

## Generar APK

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Para instalar ese APK en un telefono conectado por USB contra FloCI, ejecuta
antes `adb reverse tcp:3000 tcp:3000` mientras el tunel SSH este abierto. Para
un emulador Android usa `10.0.2.2` con el script de arriba.

El APK queda en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Modo demo (sin backend)

Para ver la app sin el tunel a FloCI (presentaciones, pruebas de diseno):

```powershell
flutter run --dart-define=USE_DEMO_MODE=true
```

En modo demo el login, el catalogo y los pedidos se sirven desde
`lib/src/data/demo_backend.dart` (en memoria). Contra el Gateway real no cambia nada.

El demo simula el flujo completo de entrega: el PIN aparece en el seguimiento
del cliente; el repartidor toma el pedido, pulsa "Retirar" y despues "Entregar"
con ese PIN. Un PIN errado descuenta intentos y al tercero se renueva. En web
no hay geocodificador ni GPS: las direcciones caen en puntos fijos cerca de
Santiago y la moto parte en el local.

## Rediseno del cliente

La experiencia del cliente sigue el diseno "Flash Drop App redesign": fondo
crema, tinta azul marino (`#0E1A35`), amarillo de marca (`#FFC72C`), azul de
acento (`#1F6BFF`) y tipografia Archivo (titulos en italica). Los tokens viven en
`lib/src/theme/client_theme.dart` (`FD`) y se aplican solo a las pantallas del
cliente con el widget `ClientTheme`; restaurante y repartidor conservan su tema.

- Navegacion inferior: Inicio, Buscar, Carrito, Pedidos y Perfil.
- Inicio: cabecera amarilla con direccion y carrito, grilla de categorias que
  filtra los comercios, banner Flash Club (aun sin backend: "Unirme" avisa que
  viene pronto), carrusel "Comercios cerca de ti" y "Lo mas pedido".
- Comercio: portada, tarjeta con calificacion, entrega y envio, barra de
  categorias fija y productos en grilla de dos columnas.
- Carrito: pestana propia con direccion, forma de pago, aviso de PIN y boton
  "PEDIR AHORA". Pedidos en curso en tarjetas amarillas con barras de avance.
- Fuente Archivo (SIL OFL 1.1) incluida en `assets/fonts/` con su licencia
  `OFL.txt`.
- `CatalogController` arma la vista por restaurante desde `/catalog/restaurants` y
  `/catalog/products`. Los campos `image`, `rating`, `deliveryTime` y `description`
  de un restaurante son opcionales: si Catalog los entrega se muestran, si no se
  ocultan (la foto usa la del primer producto).
- `CartController` mantiene el carrito entre pantallas (un local por pedido).

Pruebas: `flutter test` (logica de carrito, catalogo, backend demo y flujo de
compra completo).

## Rediseno de restaurante y repartidor

Mismo estilo que el cliente (paleta amarilla, tarjetas redondeadas, paneles
oscuros). Capturas en `docs/rediseno-roles/`.

- **Restaurante** (`/restaurant/orders/list`): cabecera del local con contadores
  (nuevos, en cocina, listos) y pestanas Nuevos / En proceso / Entregados. Cada
  tarjeta muestra hace cuanto llego el pedido y una accion rapida: "Aceptar"
  (Nuevo pedido -> Preparando) y "Marcar listo" (Preparando -> Listo para retiro).
  El detalle abre en una hoja inferior. La lista se refresca cada 30 s.
- **Repartidor** (`/delivery/orders/list`): navegacion inferior oscura con
  Pedidos, Historial y Perfil. Switch "Disponible" (se guarda en GetStorage via
  `DriverController`); desconectado no consulta pedidos. Historial con entregas
  y monto entregado.
- Los mapas usan tiles de OpenStreetMap en toda la app (Carto pedia API key).

Pruebas: `test/roles_flow_test.dart` (aceptar pedido en el local, tomar y
entregar una ruta, historial, modo desconectado y ciclo del backend demo).

## Ilustraciones e iconos

Todo el material grafico es propio de Flash Drop (widget comun:
`lib/src/widgets/ui/illustration.dart`).

- `assets/illustrations/states/`: estados vacios en SVG (carrito, pedidos,
  busqueda, direccion, ubicacion, sin conexion) y la ilustracion de error en PNG.
- `assets/illustrations/markers/`: pines del mapa (repartidor, local, entrega),
  PNG 256x276 con la punta abajo al centro.
- `assets/illustrations/address/`: iconos Casa / Trabajo / Otro, siluetas PNG de
  un solo color que la app tine.
- `assets/img/steps/`: imagenes de los pasos del pedido. `ready.png` (paso
  "Listo") es provisoria, hecha a partir de `assets/img/bag.png`; reemplazala por
  una propia de 256x256 con fondo transparente.

## Configuracion de API

No se debe cambiar una IP dentro del codigo. La app recibe la URL del Gateway
con `--dart-define=API_BASE_URL=...`. Esto permite usar Docker local, FloCI o
un entorno futuro sin volver a compilar el codigo fuente.
