import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:geolocator/geolocator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({required this.cameras, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edge Vision MVP',
      home: CameraDetectPage(cameras: cameras),
    );
  }
}

class CameraDetectPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraDetectPage({required this.cameras, Key? key}) : super(key: key);
  @override
  _CameraDetectPageState createState() => _CameraDetectPageState();
}

class _CameraDetectPageState extends State<CameraDetectPage> {
  late CameraController _controller;
  Interpreter? _interpreter;
  bool _modelLoaded = false;
  bool _sendingEvent = false;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
    );
    await _controller.initialize();
    await _loadModel();
    setState(() {});
    _startStream();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'model.tflite',
        options: InterpreterOptions()..useNNAPIForAndroid = true,
      );
      _modelLoaded = true;
    } catch (e) {
      print('Erro ao carregar modelo tflite: $e');
      _modelLoaded = false;
    }
  }

  void _startStream() {
    _controller.startImageStream((CameraImage image) async {
      if (!_modelLoaded) return;
      if (_sendingEvent) return;

      // Aqui está usando stub (simulação)
      final bool detectedCritical = _stubDetect();

      if (detectedCritical) {
        _sendingEvent = true;
        await _handleDetectedEvent();
        _sendingEvent = false;
      }
    });
  }

  // Simula detecção aleatória para demo
  bool _stubDetect() {
    final now = DateTime.now().millisecond;
    return now % 5000 < 100; // evento a cada ~5s
  }

  Future<void> _handleDetectedEvent() async {
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      print('GPS erro: $e');
    }

    final event = {
      'device_id': 'phone-001',
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'SUSPICIOUS_MOVEMENT',
      'latitude': pos?.latitude,
      'longitude': pos?.longitude,
    };

    await _sendEvent(event);
  }

  Future<void> _sendEvent(Map<String, dynamic> event) async {
    try {
      final resp = await http.post(
        Uri.parse('http://SEU_SERVIDOR:3000/api/events'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(event),
      );
      if (resp.statusCode == 200) {
        print('Evento enviado com sucesso');
      } else {
        print('Falha ao enviar evento: ${resp.statusCode}');
      }
    } catch (e) {
      print('Erro HTTP: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text('Edge Vision MVP')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: CameraPreview(_controller),
          ),
          SizedBox(height: 12),
          Text('Modelo carregado: $_modelLoaded'),
          SizedBox(height: 8),
          Text('Aguardando detecções... (stub)'),
        ],
      ),
    );
  }
}
