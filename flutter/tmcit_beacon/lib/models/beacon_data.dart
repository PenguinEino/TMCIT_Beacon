class BeaconData {
  final String uuid;
  final int major;
  final int minor;
  final double? distance;
  final String? proximity;
  final int rssi;
  final DateTime timestamp;

  BeaconData({
    required this.uuid,
    required this.major,
    required this.minor,
    this.distance,
    this.proximity,
    required this.rssi,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'BeaconData{uuid: $uuid, major: $major, minor: $minor, distance: $distance, proximity: $proximity, rssi: $rssi, timestamp: $timestamp}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeaconData &&
          runtimeType == other.runtimeType &&
          uuid == other.uuid &&
          major == other.major &&
          minor == other.minor;

  @override
  int get hashCode => uuid.hashCode ^ major.hashCode ^ minor.hashCode;

  String get identifier => '$uuid-$major-$minor';
}
