import 'package:flutter/material.dart';
import 'package:device_edg/models/risk_event.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_edg/services/event_service.dart';

class RiskConsolidationService {
  List<RiskEvent> _recentEvents = [];

  double lastCumulativeRisk = 0.0;

  VoidCallback? onRiskUpdated;

  static const Duration _consolidationWindow = Duration(seconds: 20);
  static const double _notificationThreshold = 150.0;

  static final RiskConsolidationService _instance =
      RiskConsolidationService._internal();
  factory RiskConsolidationService() => _instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final EventService _eventService = EventService();

  RiskConsolidationService._internal() {
    _initializeNotifications();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void addEvent(RiskEvent event) {
    _recentEvents.removeWhere(
      (e) => DateTime.now().difference(e.timestamp) > _consolidationWindow,
    );

    _recentEvents.add(event);

    double cumulativeRisk = _recentEvents.fold(
      0.0,
      (sum, e) => sum + e.riskScore,
    );

    lastCumulativeRisk = cumulativeRisk;

    if (onRiskUpdated != null) {
      onRiskUpdated!();
    }

    print(
      '[Consolidator] Risco Acumulado: $cumulativeRisk (Eventos: ${_recentEvents.length})',
    );

    if (cumulativeRisk >= _notificationThreshold) {
      _triggerSmartNotification();

      _recentEvents.clear();
      lastCumulativeRisk = 0.0;
    }
  }

  void _triggerSmartNotification() async {
    _recentEvents.sort((a, b) => b.riskScore.compareTo(a.riskScore));
    final highestRiskEvent = _recentEvents.first;

    final int eventCount = _recentEvents.length;
    final int consolidationWindowInSeconds = _consolidationWindow.inSeconds;

    String title = '🚨 Alerta CRÍTICO de Anomalia!';
    String body =
        'Detectados $eventCount eventos suspeitos nos últimos $consolidationWindowInSeconds segundos. '
        'Maior risco: ${highestRiskEvent.detectionType} (Risco: ${highestRiskEvent.riskScore.toStringAsFixed(0)}%).';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'anomaly_alert_channel',
          'Alertas de Anomalias Críticas',
          channelDescription:
              'Notificações importantes sobre detecções de alto risco.',
          importance: Importance.max,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: highestRiskEvent.detectionType,
    );

    print('*** NOTIFICAÇÃO DISPARADA: $title - $body ***');

    _eventService.sendDetectionEvent(
      'CRITICAL_INCIDENT_CONSOLIDATED: ${highestRiskEvent.detectionType}',
    );
  }
}
