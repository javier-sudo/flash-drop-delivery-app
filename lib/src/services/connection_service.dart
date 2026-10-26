import 'package:get/get.dart';

class ConnectionService {
  ConnectionService._();

  static final instance = ConnectionService._();

  final isOffline = false.obs;
  bool _inBackground = false;
  int _failedRequests = 0;
  DateTime _ignoreFailuresUntil = DateTime.fromMillisecondsSinceEpoch(0);

  void markOnline() {
    _failedRequests = 0;
    isOffline.value = false;
  }

  void markOffline() {
    if (_inBackground || DateTime.now().isBefore(_ignoreFailuresUntil)) return;
    _failedRequests += 1;
    // A single timeout is common while Android restores the network after the
    // app returns from the background. Show an offline state only when it
    // persists across a second request.
    if (_failedRequests >= 2) isOffline.value = true;
  }

  void enterBackground() {
    _inBackground = true;
    _failedRequests = 0;
    isOffline.value = false;
  }

  void resumeForeground() {
    _inBackground = false;
    _failedRequests = 0;
    isOffline.value = false;
    // Android may resume Dart before the device has restored its network.
    // Ignore those transient failures instead of showing a stale banner.
    _ignoreFailuresUntil = DateTime.now().add(const Duration(seconds: 15));
  }
}
