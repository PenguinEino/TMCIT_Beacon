class DetectedBeacon {
  final String uuid;
  final int major;
  final int minor;
  final int rssi;
  final double? accuracy;
  final DateTime detectedAt;

  DetectedBeacon({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.rssi,
    this.accuracy,
    required this.detectedAt,
  });

  String get uniqueId => '$uuid-$major-$minor';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DetectedBeacon &&
        other.uuid == uuid &&
        other.major == major &&
        other.minor == minor;
  }

  @override
  int get hashCode => uuid.hashCode ^ major.hashCode ^ minor.hashCode;

  @override
  String toString() {
    return 'Beacon(UUID: $uuid, Major: $major, Minor: $minor, RSSI: $rssi, Accuracy: ${accuracy?.toStringAsFixed(2) ?? "N/A"}m)';
  }

  DetectedBeacon copyWith({
    String? uuid,
    int? major,
    int? minor,
    int? rssi,
    double? accuracy,
    DateTime? detectedAt,
  }) {
    return DetectedBeacon(
      uuid: uuid ?? this.uuid,
      major: major ?? this.major,
      minor: minor ?? this.minor,
      rssi: rssi ?? this.rssi,
      accuracy: accuracy ?? this.accuracy,
      detectedAt: detectedAt ?? this.detectedAt,
    );
  }
}
