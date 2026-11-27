# Comercio: aceptacion manual y aviso de repartidor - 1.0.57

## Contrato revisado

Contrato validado contra el servidor el 26-11-2026, despues de integrar los PR
de backend #115 (aceptacion manual) y #117 (asignacion persistida en listados).
La confirmacion del pago deja el pedido en Nuevo pedido; solo Aceptar del
comercio lo pasa a Preparando.

La toma de un pedido por delivery solo cambia `deliveryId`; mantiene Listo para
retiro. `OrderListResponse` ya entrega ese campo al comercio. F9 observaba solo
`status`, por lo que no detectaba una toma sin cambio de estado.
El listado debe usar la asignacion persistida aunque no haya perfil enriquecido.

## Cambios de esta version

- La app avisa al comercio cuando detecta una asignacion nueva o diferente en un
  pedido observado previamente. No muestra identidad del repartidor ni el PIN.
- La primera consulta y la actualizacion desde versiones sin historial solo
  establecen la base. Las consultas repetidas no repiten el aviso.
- Soltar el pedido limpia el aviso; una toma posterior puede avisar de nuevo.
- La lista del comercio indica si el repartidor esta asignado, sin confundir
  asignacion con retiro. No se cambia ningun estado desde las notificaciones.
- Se conserva el pago simulado automatico del APK QA.

## Flujo de servidor integrado

Integrado por el PR de backend #115 y comprobado desde el APK:

`Pendiente de pago -> Nuevo pedido -> Aceptar -> Preparando -> Listo para retiro`.

El pago permanece APROBADO; pagar no registra acceptedAt. Solo la accion del
comercio registra la aceptacion. El evento order.created informa Nuevo pedido.
La espera de repartidor empieza al marcar Listo para retiro, como antes.
No se agregan migraciones ni se modifican pedidos existentes.
El cambio se aplica a confirmaciones nuevas: no retrocede pedidos que ya esten
en Preparando. La app es compatible con ambos comportamientos durante el despliegue.

## Prueba manual

1. Instalar el APK sobre el anterior. Permitir notificaciones y activar
   Recibiendo pedidos en el comercio; dejar que cargue la lista una vez.
2. Crear y pagar un pedido de prueba. Con el backend corregido aparecera en
   Nuevos con Aceptar/Rechazar; aceptarlo debe pasar a Preparando.
3. Marcar listo y tomarlo desde otra cuenta/telefono como repartidor.
4. El comercio debe recibir Repartidor asignado y ver Asignado en la lista.
   Actualizar varias veces no debe repetirlo; tomarlo no debe marcar Retirado.
5. Soltarlo antes del retiro y tomarlo otra vez: debe avisar de la nueva toma.

F9 sigue siendo local por sondeo: hasta 15 s en la lista y alrededor de 30 s con
el servicio activo. No es push instantaneo; Android puede restringirlo o bloquearlo
si se deniega el permiso o se fuerza la detencion.

## Resultado en celular real

El 26-11-2026 se completo un pedido de prueba entre cliente, comercio y delivery:
aceptacion, preparacion, listo, asignacion, retiro y entrega con PIN correcto.
El comercio mostro Asignado sin cambiar automaticamente a Retirado. Cliente y
comercio terminaron en Entregado. La prueba alterno cuentas en un solo celular;
no valida avisos simultaneos entre roles, sonido con app cerrada ni GPS real.
Ver `VALIDACION_1.0.57.md` para alcance y pendientes.
