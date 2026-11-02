import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Disponibilidad del repartidor. Es un estado local del teléfono: si está
/// desconectado no se piden pedidos nuevos, pero la ruta activa se mantiene.
/// (El backend aún no tiene un endpoint de disponibilidad).
class DriverController extends GetxController {
  static const _key = 'driver_available';
  final _box = GetStorage();

  late final available = RxBool(_box.read(_key) as bool? ?? true);

  void setAvailable(bool value) {
    available.value = value;
    _box.write(_key, value);
  }
}
