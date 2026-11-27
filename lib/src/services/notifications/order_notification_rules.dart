import 'dart:convert';
import 'package:proyecto_app_delivery_gessof/src/utils/delivery_assignment.dart';

/// Canales de Android. Cada uno se puede silenciar por separado desde los
/// ajustes del teléfono sin perder los demás.
enum NoticeChannel {
  /// Tienda y repartidor: pedidos nuevos o disponibles. Sonido propio.
  newOrders,

  /// Cliente: cambios de sus pedidos.
  myOrders,
}

enum NoticePriority { high, normal, silent }

/// Un aviso a mostrar. El [id] es estable: volver a mostrar un aviso con el
/// mismo id lo reemplaza en vez de sumar otro.
class OrderNotice {
  const OrderNotice({
    required this.id,
    required this.channel,
    required this.title,
    required this.body,
    required this.route,
    this.priority = NoticePriority.normal,
    this.alert = true,
    this.groupKey,
    this.isGroupSummary = false,
    this.orderId,
  });

  final int id;
  final NoticeChannel channel;
  final String title;
  final String body;

  /// Pantalla que se abre al tocar el aviso.
  final String route;
  final String? orderId;
  final NoticePriority priority;

  /// false: se actualiza el texto sin sonar ni vibrar.
  final bool alert;
  final String? groupKey;
  final bool isGroupSummary;

  String get payload =>
      jsonEncode({'route': route, if (orderId != null) 'orderId': orderId});

  @override
  String toString() => 'OrderNotice($id, $title | $body, alert: $alert)';
}

/// Resultado de aplicar las reglas: qué mostrar, qué quitar y el estado nuevo
/// que hay que guardar para la próxima consulta.
class NoticeBatch {
  const NoticeBatch({
    this.show = const [],
    this.cancel = const [],
    required this.state,
  });

  final List<OrderNotice> show;
  final List<int> cancel;
  final Map<String, dynamic> state;
}

/// Reglas de F9: qué avisar a cada rol a partir de lo que devuelve la API.
///
/// Son funciones puras: reciben el estado guardado de la consulta anterior y
/// devuelven los avisos y el estado nuevo. Así la misma lógica sirve en la
/// pantalla, en el servicio en primer plano y en el sondeo de segundo plano,
/// y un pedido no se avisa dos veces aunque lo vean los tres.
///
/// La primera consulta de cada rol solo registra lo que hay, sin avisar: si
/// no, al instalar la app o iniciar sesión sonaría por cada pedido viejo.
class OrderNotificationRules {
  OrderNotificationRules._();

  /// El aviso de pedidos disponibles suena como máximo una vez cada 2 minutos.
  static const courierSoundCooldown = Duration(minutes: 2);

  /// Con estos pedidos nuevos sin abrir, la tienda ve además un resumen.
  static const storeSummaryThreshold = 3;

  static const courierAvailableNoticeId = 9100;
  static const storeSummaryNoticeId = 9200;
  static const storeGroupKey = 'flashdrop.store.new_orders';

  static const _routeClient = '/client/orders/tracking';
  static const _routeStore = '/restaurant/orders/list';
  static const _routeCourier = '/delivery/orders/list';

  // ------------------------------------------------------------------ cliente

  static NoticeBatch client(
    Map<String, dynamic>? previous,
    List<Map<String, dynamic>> orders,
  ) {
    final seeded = previous != null;
    final statuses = _stringMap(previous?['statuses']);
    final codes = _stringMap(previous?['codes']);
    final nextStatuses = <String, String>{};
    final nextCodes = <String, String>{};
    final show = <OrderNotice>[];

    for (final order in orders) {
      final id = _orderId(order);
      final status = _status(order);
      if (id.isEmpty || status.isEmpty) continue;
      nextStatuses[id] = status;

      final code = '${order['deliveryCode'] ?? ''}'.trim();
      if (code.isNotEmpty) nextCodes[id] = _fingerprint(code);

      if (!seeded) continue;
      final before = statuses[id];
      if (before != null && before != status) {
        final notice = _clientStatusNotice(id, order, before, status);
        if (notice != null) show.add(notice);
      }

      // Al 3.er código errado el backend lo renueva sin cambiar el estado.
      final codeBefore = codes[id];
      if (codeBefore != null &&
          nextCodes[id] != null &&
          codeBefore != nextCodes[id] &&
          _isOnTheWay(status)) {
        show.add(
          OrderNotice(
            id: _noticeId('client:$id:code:${nextCodes[id]}'),
            channel: NoticeChannel.myOrders,
            priority: NoticePriority.high,
            title: 'Tu código de entrega cambió',
            body: 'Ábrelo en la app para dárselo al repartidor.',
            route: _routeClient,
            orderId: id,
          ),
        );
      }
    }

    return NoticeBatch(
      show: show,
      state: {'statuses': nextStatuses, 'codes': nextCodes},
    );
  }

  static OrderNotice? _clientStatusNotice(
    String id,
    Map<String, dynamic> order,
    String before,
    String status,
  ) {
    final s = status.toLowerCase();
    final label = _label(order);
    String? title;
    String? body;
    var priority = NoticePriority.normal;

    if (s.contains('nuevo')) {
      title = 'Pedido $label recibido';
      body = 'El local recibió tu pedido.';
    } else if (s.contains('preparando')) {
      title = 'Pedido $label';
      body = 'Están preparando tu pedido.';
      priority = NoticePriority.silent;
    } else if (_isOnTheWay(status)) {
      // Retirado y En camino son la misma noticia para el cliente.
      if (_isOnTheWay(before)) return null;
      final needsCode =
          '${order['receptionMode'] ?? ''}'.toUpperCase() == 'SEGURO' ||
          '${order['deliveryCode'] ?? ''}'.trim().isNotEmpty;
      title = 'Tu pedido va en camino';
      // El código nunca va en el aviso: se vería con el teléfono bloqueado.
      body = needsCode
          ? 'Ten a mano tu código de entrega.'
          : 'El repartidor ya retiró tu pedido $label.';
      priority = NoticePriority.high;
    } else if (s.contains('entregado')) {
      title = 'Pedido entregado';
      body = '¡Buen provecho!';
    } else if (s.contains('rechazado')) {
      title = 'Pedido $label no aceptado';
      body = 'El local no pudo aceptar tu pedido.';
      priority = NoticePriority.high;
    } else if (s.contains('cancelado')) {
      title = 'Pedido $label cancelado';
      body = 'Revisa el detalle en la app.';
      priority = NoticePriority.high;
    }
    // "Listo para retiro" y "Pendiente de pago" no cambian nada para el cliente.
    if (title == null || body == null) return null;

    return OrderNotice(
      id: _noticeId('client:$id:$s'),
      channel: NoticeChannel.myOrders,
      priority: priority,
      title: title,
      body: body,
      route: _routeClient,
      orderId: id,
    );
  }

  // ------------------------------------------------------------------ tienda

  static NoticeBatch store(
    Map<String, dynamic>? previous,
    List<Map<String, dynamic>> orders,
  ) {
    final seeded = previous != null;
    final statuses = _stringMap(previous?['statuses']);
    final assignments = _stringMap(previous?['assignments']);
    final next = <String, String>{};
    final nextAssignments = <String, String>{};
    final show = <OrderNotice>[];
    final cancel = <int>[];
    var pendingPreparation = 0;

    for (final order in orders) {
      final id = _orderId(order);
      final status = _status(order);
      if (id.isEmpty || status.isEmpty) continue;
      next[id] = status;
      final courier = assignedCourierId(order) ?? '';
      nextAssignments[id] = courier;
      final s = status.toLowerCase();
      final isNew = s.contains('nuevo');
      final isPreparing = s.contains('preparando');
      final needsPreparation = isNew || isPreparing;
      if (needsPreparation) pendingPreparation++;

      final before = statuses[id];
      final wasUnpaid =
          before != null &&
          before.toLowerCase().contains('pendiente') &&
          before.toLowerCase().contains('pago');
      final noticeId = _noticeId('store:$id');
      if (!seeded) continue;

      // Tomar el pedido solo cambia deliveryId; el estado sigue listo para retiro.
      // Sin historial de asignaciones (primera consulta o actualizacion del APK), no se avisa de pedidos viejos.
      final courierNoticeId = _noticeId('store:$id:courier');
      final beforeCourier = assignments[id];
      final canBeAssigned =
          (s.contains('listo') && s.contains('retiro')) || _isOnTheWay(status);
      if (beforeCourier != null &&
          before != null &&
          !_isFinal(before) &&
          courier.isNotEmpty &&
          courier != beforeCourier &&
          canBeAssigned) {
        show.add(
          OrderNotice(
            id: courierNoticeId,
            channel: NoticeChannel.newOrders,
            priority: NoticePriority.high,
            title: 'Repartidor asignado a ${_label(order)}',
            body: 'Un repartidor tomo el pedido para retirarlo.',
            route: _routeStore,
            orderId: id,
          ),
        );
      } else if (_isFinal(status) ||
          (beforeCourier != null &&
              beforeCourier.isNotEmpty &&
              courier.isEmpty)) {
        cancel.add(courierNoticeId);
      }

      // F7 activates paid orders directly in Preparando, including orders
      // that were already seen while payment was still pending.
      if (needsPreparation && (before == null || wasUnpaid)) {
        show.add(
          OrderNotice(
            id: noticeId,
            channel: NoticeChannel.newOrders,
            priority: NoticePriority.high,
            title: 'Nuevo pedido ${_label(order)}',
            body: 'Revísalo en tus pedidos.',
            route: _routeStore,
            orderId: id,
            groupKey: storeGroupKey,
          ),
        );
      } else if (before != null && before != status) {
        final wasActive = !_isFinal(before);
        if (s.contains('cancelado') && wasActive) {
          show.add(
            OrderNotice(
              id: noticeId,
              channel: NoticeChannel.newOrders,
              priority: NoticePriority.high,
              title: 'Pedido ${_label(order)} cancelado',
              body: 'No lo prepares.',
              route: _routeStore,
              orderId: id,
              groupKey: storeGroupKey,
            ),
          );
        } else if ((before.toLowerCase().contains('nuevo') && !isNew) ||
            (before.toLowerCase().contains('preparando') && !isPreparing)) {
          // La tienda ya lo atendió: el aviso de pedido nuevo sobra.
          cancel.add(noticeId);
        }
      }
    }

    if (seeded) {
      if (pendingPreparation >= storeSummaryThreshold) {
        show.add(
          OrderNotice(
            id: storeSummaryNoticeId,
            channel: NoticeChannel.newOrders,
            priority: NoticePriority.high,
            // El resumen se actualiza sin volver a sonar: ya sonó cada pedido.
            alert: false,
            title: '$pendingPreparation pedidos por preparar',
            body: 'Revísalos en tus pedidos.',
            route: _routeStore,
            groupKey: storeGroupKey,
            isGroupSummary: true,
          ),
        );
      } else {
        cancel.add(storeSummaryNoticeId);
      }
    }

    return NoticeBatch(
      show: show,
      cancel: cancel,
      state: {'statuses': next, 'assignments': nextAssignments},
    );
  }

  // ------------------------------------------------------------------ repartidor

  /// Pedidos disponibles para retirar: un solo aviso que se reemplaza.
  ///
  /// [canTake] es false si el repartidor está "No disponible" o ya tiene una
  /// ruta en curso (orders no le deja tomar otro): en ese caso no se avisa.
  static NoticeBatch courierAvailable(
    Map<String, dynamic>? previous,
    List<Map<String, dynamic>> available, {
    required bool canTake,
    required DateTime now,
  }) {
    final seen = _stringList(previous?['seen']).toSet();
    final lastSoundMs = previous?['lastSoundMs'] as int?;
    final ids = <String>[];
    final byRestaurant = <String, int>{};
    for (final order in available) {
      final id = _orderId(order);
      if (id.isEmpty) continue;
      ids.add(id);
      final name = '${order['restaurantName'] ?? 'Local'}'.trim();
      byRestaurant[name] = (byRestaurant[name] ?? 0) + 1;
    }

    final state = <String, dynamic>{
      'seen': ids,
      if (lastSoundMs != null) 'lastSoundMs': lastSoundMs,
    };

    if (!canTake || ids.isEmpty) {
      return NoticeBatch(
        cancel: const [courierAvailableNoticeId],
        state: state,
      );
    }

    final hasNew = ids.any((id) => !seen.contains(id));
    final changed = hasNew || seen.length != ids.length;
    // Primera consulta: se registra lo que hay sin avisar.
    if (previous == null || !changed) {
      return NoticeBatch(state: state);
    }

    final cooledDown =
        lastSoundMs == null ||
        now.millisecondsSinceEpoch - lastSoundMs >=
            courierSoundCooldown.inMilliseconds;
    final alert = hasNew && cooledDown;
    if (alert) state['lastSoundMs'] = now.millisecondsSinceEpoch;

    final count = ids.length;
    return NoticeBatch(
      show: [
        OrderNotice(
          id: courierAvailableNoticeId,
          channel: NoticeChannel.newOrders,
          priority: NoticePriority.high,
          alert: alert,
          title: count == 1
              ? '1 pedido disponible'
              : '$count pedidos disponibles',
          body: '${_restaurantsSummary(byRestaurant)} · toca para ver',
          route: _routeCourier,
        ),
      ],
      state: state,
    );
  }

  /// Ruta propia del repartidor: solo se avisa si un pedido se cancela
  /// (soporte o bloqueo por código). El resto lo hace él mismo.
  static NoticeBatch courierRoutes(
    Map<String, dynamic>? previous,
    List<Map<String, dynamic>> routes,
  ) {
    final seeded = previous != null;
    final statuses = _stringMap(previous?['statuses']);
    final next = <String, String>{};
    final show = <OrderNotice>[];

    for (final route in routes) {
      final id = _orderId(route);
      final status = _status(route);
      if (id.isEmpty || status.isEmpty) continue;
      next[id] = status;
      final before = statuses[id];
      if (!seeded || before == null || before == status) continue;
      final s = status.toLowerCase();
      if ((s.contains('cancelado') || s.contains('rechazado')) &&
          !_isFinal(before)) {
        show.add(
          OrderNotice(
            id: _noticeId('courier:$id:cancel'),
            channel: NoticeChannel.newOrders,
            priority: NoticePriority.high,
            title: 'Pedido ${_label(route)} cancelado',
            body: 'Ya no tienes que entregarlo.',
            route: _routeCourier,
            orderId: id,
          ),
        );
      }
    }
    return NoticeBatch(show: show, state: {'statuses': next});
  }

  /// true si el repartidor tiene una ruta sin terminar.
  static bool hasActiveRoute(List<Map<String, dynamic>> routes) {
    return routes.any((r) {
      final s = _status(r).toLowerCase();
      return s.isNotEmpty && !_isFinal(s);
    });
  }

  // ------------------------------------------------------------------ utilidades

  static String _orderId(Map<String, dynamic> order) =>
      '${order['orderId'] ?? order['id'] ?? ''}'.trim();

  static String _status(Map<String, dynamic> order) =>
      '${order['status'] ?? ''}'.trim();

  static String _label(Map<String, dynamic> order) {
    final code = '${order['code'] ?? ''}'.trim();
    if (code.isNotEmpty) return code;
    return '#${_orderId(order)}';
  }

  static bool _isOnTheWay(String status) {
    final s = status.toLowerCase();
    return s.contains('retirado') || s.contains('camino');
  }

  static bool _isFinal(String status) {
    final s = status.toLowerCase();
    return s.contains('entregado') ||
        s.contains('cancelado') ||
        s.contains('rechazado');
  }

  static String _restaurantsSummary(Map<String, int> byRestaurant) {
    final parts = byRestaurant.entries
        .map((e) => e.value > 1 ? '${e.key} (${e.value})' : e.key)
        .toList();
    if (parts.length <= 3) return parts.join(', ');
    return '${parts.take(3).join(', ')} y ${parts.length - 3} más';
  }

  /// Huella del código para detectar que cambió sin guardar el código.
  static String _fingerprint(String code) =>
      _noticeId('fd-code:$code').toRadixString(16);

  /// Id de 31 bits estable entre ejecuciones (FNV-1a). `String.hashCode` no
  /// sirve: puede cambiar entre el proceso principal y el de segundo plano.
  static int _noticeId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(key)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final id = hash & 0x7fffffff;
    // Los ids fijos (9100, 9200, ...) quedan reservados.
    return id < 10000 ? id + 10000 : id;
  }

  static Map<String, String> _stringMap(Object? raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry('$k', '$v'));
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => '$e').toList();
  }
}
