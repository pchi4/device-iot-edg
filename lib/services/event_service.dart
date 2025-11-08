import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class EventService {
  static const String _apiUrl = 'http://192.168.1.102:3000';
  static const String _boxName = 'offline_events';

  bool _initialized = false;

  Future<void> _initHive() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    await Hive.openBox(_boxName);
    _initialized = true;
  }

  Future<Position?> getCurrentLocation() async {
    // 1. CHECAR SE O GPS ESTÁ ATIVO NO DISPOSITIVO
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Se estiver desligado, o erro é 'service_disabled', não 'denied'.
      // Peça ao usuário para ligar o GPS.
      print("GPS erro: Serviço de localização está desligado.");
      return null;
    }

    // 2. CHECAR O STATUS DA PERMISSÃO
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Tenta solicitar a permissão novamente (se o diálogo aparecerá)
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("GPS erro: Permissão negada ou negada permanentemente.");
        return null;
      }
    }

    // 3. OBTER A POSIÇÃO
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        // Garante que o método não faça uma requisição única demorada,
        // mas sim que use o último local conhecido rapidamente.
      );
    } catch (e) {
      print("GPS erro: Falha ao obter posição: $e");
      return null;
    }
  }

  Future<void> sendDetectionEvent(String detectionType) async {
    await _initHive();
    final box = Hive.box(_boxName);
    final pos = await getCurrentLocation();

    final event = {
      'device_id': 'phone-001',
      'timestamp': DateTime.now().toIso8601String(),
      'type': detectionType,
      'latitude': pos?.latitude,
      'longitude': pos?.longitude,
    };

    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none) {
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

  Future<void> sendFeedbackEvent({
    required String userCorrection,
    required String detectedLabel,
    required double confidence,
  }) async {
    await _initHive();
    final box = Hive.box(_boxName);
    final pos = await getCurrentLocation();

    final feedbackPayload = {
      'device_id': 'phone-001',
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'user_feedback', // Tipo de evento específico para retreinamento
      'detected_label': detectedLabel,
      'user_correction': userCorrection,
      'confidence': confidence,
      'latitude': pos?.latitude,
      'longitude': pos?.longitude,
    };

    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none) {
      await box.add(feedbackPayload);
      print('📦 Feedback salvo localmente (offline)');
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse('$_apiUrl/api/events'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(feedbackPayload),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        print(
          '✅ Feedback enviado com sucesso para o servidor de retreinamento.',
        );
      } else {
        await box.add(feedbackPayload);
        print('⚠️ Falha ao enviar feedback. Salvo localmente.');
      }
    } catch (e) {
      await box.add(feedbackPayload);
      print('❌ Erro HTTP, feedback salvo localmente: $e');
    }
  }
}
