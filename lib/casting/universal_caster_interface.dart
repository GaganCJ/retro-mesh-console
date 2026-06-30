enum CastingProtocol { googleCast, appleAirPlay, androidPresentation }

class UniversalTVTarget {
  final String id;
  final String name;
  final CastingProtocol protocolType;

  const UniversalTVTarget({
    required this.id,
    required this.name,
    required this.protocolType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocolType': protocolType.name,
      };

  factory UniversalTVTarget.fromJson(Map<String, dynamic> json) {
    return UniversalTVTarget(
      id: json['id'] as String,
      name: json['name'] as String,
      protocolType: CastingProtocol.values.firstWhere(
        (e) => e.name == json['protocolType'],
        orElse: () => CastingProtocol.googleCast,
      ),
    );
  }
}

abstract class UniversalDisplayCaster {
  Stream<List<UniversalTVTarget>> get discoveredDevicesStream;
  Future<void> startScanning();
  Future<void> stopScanning();
  Future<void> connectToDevice(UniversalTVTarget target);
  Future<void> projectGameplayCanvas();
  Future<void> disconnect();
}
