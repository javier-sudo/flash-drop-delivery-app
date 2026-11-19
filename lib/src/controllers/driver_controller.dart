import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:proyecto_app_delivery_gessof/src/services/notifications/notice_store.dart';
import 'package:proyecto_app_delivery_gessof/src/services/order_watch_service.dart';

/// Disponibilidad del repartidor. Es un estado local del teléfono: si está
/// desconectado no se piden pedidos nuevos, pero la ruta activa se mantiene.
/// (El backend aún no tiene un endpoint de disponibilidad).
class DriverController extends GetxController {
  static const _key = 'driver_available';
  final _box = GetStorage();

  late final available = RxBool(_box.read(_key) as bool? ?? true);

  @override
  void onInit() {
    super.onInit();
    // Copia el valor guardado en GetStorage al almacén que lee el servicio
    // (por si viene de una versión anterior) y arranca o detiene el servicio.
    NoticeStore.instance
        .setDriverAvailable(available.value)
        .catchError((_) {})
        .then((_) => OrderWatchService.refresh());
  }

  Future<void> setAvailable(bool value) async {
    available.value = value;
    await _box.write(_key, value);
    // El servicio en primer plano y el sondeo leen este valor desde otro
    // isolate, donde GetStorage no ve los cambios.
    try {
      await NoticeStore.instance.setDriverAvailable(value);
    } catch (_) {}
    await OrderWatchService.refresh();
  }
}
