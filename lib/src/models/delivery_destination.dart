/// The selected delivery address, never a default map center or device GPS.
class DeliveryDestination {
  const DeliveryDestination({
    required this.address,
    required this.commune,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final String commune;
  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is DeliveryDestination &&
      address == other.address &&
      commune == other.commune &&
      latitude == other.latitude &&
      longitude == other.longitude;

  @override
  int get hashCode => Object.hash(address, commune, latitude, longitude);

  static DeliveryDestination? fromStorage(dynamic raw) {
    if (raw is! Map) return null;
    final address = '${raw['address'] ?? ''}'.trim();
    final commune = '${raw['commune'] ?? ''}'.trim();
    final latitude = double.tryParse('${raw['lat']}');
    final longitude = double.tryParse('${raw['lng']}');
    if (address.length < 6 ||
        commune.isEmpty ||
        commune.length > 120 ||
        latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return DeliveryDestination(
      address: address,
      commune: commune,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
