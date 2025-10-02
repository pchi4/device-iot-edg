// lib/services/event_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class EventService {
  static const String _apiUrl = 'http://10.0.2.2:3000';

  Future<Position?> _getGeolocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      print('GPS erro: $e');
      return null;
    }
  }

  Future<void> sendDetectionEvent(String detectionType) async {
    final pos = await _getGeolocation();

    final event = {
      'device_id': 'phone-001',
      'timestamp': DateTime.now().toIso8601String(),
      'type': detectionType,
      'latitude': pos?.latitude,
      'longitude': pos?.longitude,
    };

    try {
      final resp = await http.post(
        Uri.parse('$_apiUrl/api/events'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(event),
      );
    } catch (e) {
      print('❌ Erro HTTP ao enviar evento: $e');
    }
  }

  Future<List<dynamic>> fetchAnomalies() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/events'));

      if (response.statusCode == 200) {
        final rawData = response.body;
        final List<dynamic> data = jsonDecode(rawData);
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
