// lib/services/event_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class EventService {
  // Use o IP apropriado para seu ambiente:
  // - '10.0.2.2' (Emulador Android)
  // - '127.0.0.1' (Simulador iOS)
  // - Seu IP de rede (Dispositivo real)
  static const String _apiUrl = 'http://127.0.0.1:3000';

  Future<Position?> _getGeolocation() async {
    try {
      // Usando 'best' como correção para o erro anterior
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
      'type': detectionType, // Ex: 'SUSPICIOUS_MOVEMENT'
      'latitude': pos?.latitude,
      'longitude': pos?.longitude,
    };

    try {
      final resp = await http.post(
        Uri.parse('$_apiUrl/api/events'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(event),
      );

      if (resp.statusCode == 200) {
        print('✅ Evento "$detectionType" enviado com sucesso!');
      } else {
        print('⚠️ Falha ao enviar evento. Status: ${resp.statusCode}');
      }
    } catch (e) {
      print('❌ Erro HTTP ao enviar evento: $e');
    }
  }

  Future<List<dynamic>> fetchAnomalies() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/events'));

      if (response.statusCode == 200) {
        final rawData = response.body;
        print('✅ DADOS RECEBIDOS: $rawData');
        final List<dynamic> data = jsonDecode(rawData);
        return data;
      } else {
        print('⚠️ Falha ao carregar anomalias. Status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erro de conexão ao buscar anomalias: $e');
      // Retorna uma lista vazia em caso de falha de rede/conexão
      return [];
    }
  }
}
