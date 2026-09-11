# Integracion Flutter con FlashDrop

La app consume un unico punto de entrada: el API Gateway. Nunca se conecta a las
bases de datos ni usa directamente los puertos internos de Auth, Catalog, Orders o
Delivery.

## Ejecutar la app

Con el stack levantado localmente:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` es la direccion del host vista desde el emulador Android. Para Windows,
Linux o macOS se usa `http://127.0.0.1:3000`. Para Floci primero se abre el tunel:

```powershell
ssh -N -L 3000:127.0.0.1:3000 dev@76.13.168.23
```

Luego se usa la misma URL local. Un telefono fisico requiere una URL accesible desde
el dispositivo; `localhost` no sirve porque apunta al propio telefono.

## Contratos que consume la app

| Servicio | Ruta del Gateway | Uso en Flutter | Condicion |
| --- | --- | --- | --- |
| Auth | `POST /auth/register` | Crear cuenta con JSON | No soporta foto de perfil. |
| Auth | `POST /auth/login` | Obtener `accessToken`, `refreshToken`, usuario y roles | Debe devolver `userId`, `name`, `email`, `roles`, `accessToken`, `refreshToken`. |
| Auth | `GET /auth/profile` | Futuro refresco de perfil | Requiere `Authorization: Bearer`. |
| Catalog | `GET /catalog/products` | Catalogo y carrito | Es publico. Devuelve una lista, no un objeto `data`. |
| Orders | `GET /api/orders` | Historial de cliente y restaurante | Requiere JWT. |
| Orders | `POST /api/orders` | Crear pedido | Requiere JWT; el usuario se toma del token. |
| Orders | `GET /api/orders/{id}` | Seguimiento del pedido | Requiere JWT. El id es UUID. |
| Orders | `PUT /api/orders/{id}/status` | Cambiar estado desde restaurante | Requiere JWT. |
| Delivery | `GET /api/delivery/routes` | Rutas del repartidor | Requiere JWT y un repartidor asociado al usuario. |
| Delivery | `POST /api/delivery/claim` | Tomar pedidos | Requiere JWT. |

## Pendientes de los servicios

1. **Auth**: si se quiere conservar la imagen elegida durante el registro, debe
   agregar un endpoint autenticado de foto de perfil. La app muestra el selector,
   pero no envia el archivo porque la API actual no tiene esa ruta.
2. **Catalog**: el listado publico entrega `categoryId` y `restaurantId`, pero no los
   nombres. Para filtros y tarjetas mas descriptivas conviene incluir
   `categoryName` y `restaurantName`, o exponer endpoints de consulta que la app
   pueda usar eficientemente.
3. **Orders**: mantener IDs `Long` en el contrato HTTP de `userId` y `productId`, y
   UUID solo para el identificador del pedido. La app ya envia los productos como
   numeros y usa el usuario del JWT.
4. **Delivery**: confirmar el contrato de `POST /api/delivery/claim` y que los IDs
   de ruta/pedido que devuelve sean estables. La vista permite agrupar hasta tres
   pedidos del mismo punto de retiro.
5. **Administracion**: el usuario `admin` actual es solo multirol. Un panel admin
   real necesita endpoints y permisos para usuarios, roles, restaurantes, productos
   y metricas.

## Seguridad de cliente

La app agrega `Authorization: Bearer <accessToken>` a Orders y Delivery. Para una
version de produccion, el token debe guardarse en almacenamiento seguro del sistema
en vez de `GetStorage`.
