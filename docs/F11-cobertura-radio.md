# F11: cobertura por radio

## Alcance

- Comercio: acceso a **Zona de despacho** desde el icono de radar en pedidos
  del local. Pin seleccionable en mapa, coordenadas editables y radio entre
  1 y 50 km (hasta dos decimales); accesos de 5, 10, 15 y 20 km.
- Cliente: direccion seleccionada con coordenadas y comuna antes de consultar
  el catalogo. Inicio, busqueda, categorias y productos solo muestran locales
  con cobertura.
- Al cambiar la direccion se vacia el listado anterior y se consulta de nuevo.
  Una respuesta tardia no puede reemplazar resultados de la nueva direccion.
- Carrito: conserva los productos, pero bloquea la compra si el destino queda
  fuera del radio. Antes de crear el pedido vuelve a consultar la cobertura y
  envia `latitude`, `longitude` y `commune` al servidor.

## Contrato y dependencias

Requiere el PR F11 del backend basado en `main` 69f887a:

```text
GET /catalog/restaurants?latitude=...&longitude=...
GET /api/catalog/my/restaurant
PUT /api/catalog/my/restaurant/location
PUT /api/catalog/my/restaurant/delivery-radius
```

El PUT del radio envia `{"deliveryRadiusKm":5}` con JWT del propietario.
La medicion es geografica en linea recta (haversine, precision de dos decimales),
no kilometros por calles. La comuna se conserva pero no determina el radio.
Orders revalida al cotizar y crear: la interfaz no es una barrera de seguridad.

No incluye F9 (#14), F4 (#13), F10 ni el flujo de pago de F8. El `main` del
backend ya requiere Tarjeta/pago confirmado: la integracion de pagos del
cliente sigue siendo una dependencia separada para QA de una compra completa.

## Publicacion coordinada

1. Revisar ambos PR; no se ha modificado el servidor ni la base productiva.
2. Aplicar V10 de Catalog por el procedimiento de despliegue y publicar Catalog.
3. Configurar ubicacion y radio reales de los comercios antes de activar el filtro.
4. Actualizar los consumidores web/movil para enviar destino con coordenadas.
5. Activar Orders con validacion obligatoria y comprobar ambos clientes.

Los locales sin pin o sin radio no tienen cobertura; no se les asigna un radio
por defecto. Las direcciones antiguas sin comuna deben confirmarse nuevamente.
No se solicita GPS continuo ni permiso de ubicacion en segundo plano.

## QA manual pendiente

- Comercio configura 5 km: cliente dentro ve sus productos, cliente fuera no.
- Cambiar a 10 km incorpora una direccion antes excluida.
- Cambiar direccion durante una carga no muestra locales del destino anterior.
- Con carrito abierto, cambiar a una direccion fuera bloquea el boton sin
  borrar productos. Volver dentro habilita nuevamente la compra.
- Falla de red: estado recuperable; no volver a mostrar todo el catalogo.
- Radio invalido y usuario sin rol: rechazar sin cambiar otro local.
- Probar pin, geocodificacion y comuna en Android real.
- Despues del despliegue, comprobar por API que un pedido directo fuera del
  radio no genera pedido ni cobro, aunque omita la consulta del catalogo.

Los tests automatizados cubren filtrado, errores, respuestas tardias, carrito,
serializacion del destino y guardado del radio. No sustituyen QA en servidor.
