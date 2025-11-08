class RiskEvent {
  final DateTime timestamp;
  final String detectionType;
  final double confidence;
  final double riskScore;
  final double? latitude;
  final double? longitude;

  RiskEvent({
    required this.timestamp,
    required this.detectionType,
    required this.confidence,
    required this.riskScore,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'detectionType': detectionType,
    'confidence': confidence,
    'riskScore': riskScore,
  };

  factory RiskEvent.fromJson(Map<String, dynamic> json) => RiskEvent(
    timestamp: DateTime.parse(json['timestamp']),
    detectionType: json['detectionType'],
    confidence: json['confidence'],
    riskScore: json['riskScore'],
    latitude: json['latitude'],
    longitude: json['longitude'],
  );
  RiskEvent copyWith({
    DateTime? timestamp,
    String? detectionType,
    double? confidence,
    double? riskScore,
    double? latitude,
    double? longitude,
  }) {
    return RiskEvent(
      timestamp: timestamp ?? this.timestamp,
      detectionType: detectionType ?? this.detectionType,
      confidence: confidence ?? this.confidence,
      riskScore: riskScore ?? this.riskScore,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
