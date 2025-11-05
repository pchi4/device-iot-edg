// lib/services/event_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class EventService {
  static const String _apiUrl = 'http://10.0.2.2:3000';
  static const String _boxName = 'offline_events';

  bool _initialized = false;

  Future<void> _initHive() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    await Hive.openBox(_boxName);
    _initialized = true;
  }

  Future<Position?> _getGeolocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      print('⚠️ GPS erro: $e');
      return null;
    }
  }

  Future<void> sendDetectionEvent(String detectionType) async {
    await _initHive();
    final box = Hive.box(_boxName);
    final pos = await _getGeolocation();

    final event = {
      'device_id': 'phone-001',
      'timestamp': DateTime.now().toIso8601String(),
      'type': detectionType,
      'latitude': pos?.latitude,
      'longitude': pos?.longitude,
    };

    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none) {
      // sem internet → salva local
      await box.add(event);
      print('📦 Evento salvo localmente (offline)');
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse('$_apiUrl/api/events'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(event),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        print('✅ Evento enviado com sucesso');
      } else {
        // erro → salva local
        await box.add(event);
        print('⚠️ Falha ao enviar evento. Salvo localmente.');
      }
    } catch (e) {
      await box.add(event);
      print('❌ Erro HTTP, evento salvo localmente: $e');
    }
  }

  Future<void> syncOfflineEvents() async {
    await _initHive();
    final box = Hive.box(_boxName);

    if (box.isEmpty) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    final List pending = box.values.toList();
    for (final event in pending) {
      try {
        final resp = await http.post(
          Uri.parse('$_apiUrl/api/events'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(event),
        );

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          await box.deleteAt(0);
          print('🔁 Evento sincronizado com sucesso!');
        }
      } catch (e) {
        print('❌ Falha ao sincronizar evento: $e');
        break;
      }
    }
  }

  Future<List<dynamic>> fetchAnomalies() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/events'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        print('⚠️ Falha ao carregar anomalias. Status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erro de conexão ao buscar anomalias: $e');
      return [];
    }
  }
}
