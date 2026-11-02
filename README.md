# Flash Drop Delivery App

Aplicacion Flutter multirol para un prototipo de delivery tipo Uber Eats.

## Funcionalidades

- Cliente: catalogo, busqueda, carrito, direccion, pedido e historial con seguimiento.
- Restaurante: pedidos del local, detalle del cliente, productos, pago y cambio de estado.
- Repartidor: toma pedidos disponibles, agrupa hasta 3 pedidos, ve ruta en mapa y marca entregas.
- Backend conectado al API Gateway de FlashDrop. La URL se entrega al ejecutar o
  compilar mediante `API_BASE_URL`.

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

## Configuracion de API

No se debe cambiar una IP dentro del codigo. La app recibe la URL del Gateway
con `--dart-define=API_BASE_URL=...`. Esto permite usar Docker local, FloCI o
un entorno futuro sin volver a compilar el codigo fuente.
