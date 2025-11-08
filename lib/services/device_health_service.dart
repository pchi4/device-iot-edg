import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_edg/services/tflite_service.dart';
import 'package:flutter/material.dart';

class DeviceHealthService {
  int batteryLevel = 100;
  BatteryState batteryState = BatteryState.full;

  String cpuStatus = 'Inicializando...';
  double lastCpuLoad = 0.0;

  final Battery _battery = Battery();
  Timer? _pollingTimer;

  static final DeviceHealthService _instance = DeviceHealthService._internal();
  factory DeviceHealthService() => _instance;
  DeviceHealthService._internal();

  VoidCallback? _onDataUpdated;

  void setUpdateListener(VoidCallback listener) {
    _onDataUpdated = listener;
  }

  void startMonitoring() async {
    try {
      batteryLevel = await _battery.batteryLevel;
      batteryState = await _battery.batteryState;
    } catch (e) {
      print("⚠️ Erro ao obter status inicial da bateria: $e");
    }

    _battery.onBatteryStateChanged.listen((state) {
      batteryState = state;
      if (_onDataUpdated != null) {
        _onDataUpdated!();
      }
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _pollHealthData();
    });

    print("✅ Monitoramento de Saúde Iniciado. Polling a cada 10s.");

    _pollHealthData();
  }

  void _pollHealthData() async {
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (e) {
      print("⚠️ Erro ao obter nível de bateria: $e");
    }

    final isLiteModel = TfliteService().activeTier == ModelTier.lite;

    if (batteryLevel < 20 && batteryState == BatteryState.discharging) {
      cpuStatus = 'ALTO STRESS CRÍTICO';
      lastCpuLoad = 0.90;
    } else if (isLiteModel) {
      cpuStatus = 'MODO DE ECONOMIA (LITE)';
      lastCpuLoad = 0.50;
    } else {
      cpuStatus = 'Normal';
      lastCpuLoad = 0.30;
    }

    if (_onDataUpdated != null) {
      _onDataUpdated!();
    }
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _onDataUpdated = null;
    print("🛑 Monitoramento de Saúde Parado.");
  }
}
