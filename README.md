# Flash Drop Delivery App

Aplicacion Flutter multirol para un prototipo de delivery tipo Uber Eats.

## Funcionalidades

- Cliente: catalogo, busqueda, carrito, direccion, pedido e historial con seguimiento.
- Restaurante: pedidos del local, detalle del cliente, productos, pago y cambio de estado.
- Repartidor: toma pedidos disponibles, agrupa hasta 3 pedidos, ve ruta en mapa y marca entregas.
- Backend publico conectado a Supabase: `https://flash-drop-delivery.vercel.app`.

## Credenciales demo

Todas usan la contrasena `123456`.

- Cliente: `cliente@demo.cl`
- Restaurante: `restaurante@demo.cl`
- Repartidor: `repartidor@demo.cl`
- Multirol: `admin@demo.cl`
- Restaurante Arauco Maipu: `araucomaipu@flashdrop.cl`

## Requisitos

- Flutter SDK instalado.
- Android Studio o un dispositivo Android conectado.

## Ejecutar en desarrollo

```bash
flutter pub get
flutter run
```

## Generar APK

```bash
flutter build apk --release
```

El APK queda en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Configuracion de API

La URL del backend se configura en:

```text
lib/src/environment/environment.dart
```
