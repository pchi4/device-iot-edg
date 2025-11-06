class RiskEvent {
  final DateTime timestamp;
  final String
  detectionType; // Ex: 'Pessoa', 'Movimento Anômalo', 'Objeto Desconhecido'
  final double confidence; // Confiança do modelo (0.0 a 1.0)
  final double riskScore; // Pontuação de risco calculada (0.0 a 100.0)

  RiskEvent({
    required this.timestamp,
    required this.detectionType,
    required this.confidence,
    required this.riskScore,
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
  );
}
