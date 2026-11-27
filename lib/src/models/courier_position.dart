import 'package:latlong2/latlong.dart';

class CourierPosition {
  const CourierPosition(this.coordinates, this.recordedAt);
  final LatLng coordinates;
  final DateTime recordedAt;

  static CourierPosition? fromJson(
    Map<String, dynamic> json, {
    required Object routeId,
    DateTime? now,
  }) {
    if ('${json['routeId']}' != '$routeId') return null;
    final lat = double.tryParse('${json['latitude']}');
    final lng = double.tryParse('${json['longitude']}');
    final time = DateTime.tryParse('${json['recordedAt']}');
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        time == null) {
      return null;
    }
    final age = (now ?? DateTime.now()).difference(time);
    if (age > const Duration(seconds: 30) ||
        age < const Duration(seconds: -5)) {
      return null;
    }
    return CourierPosition(LatLng(lat, lng), time);
  }
}
