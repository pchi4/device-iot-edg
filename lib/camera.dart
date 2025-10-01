// imports omitidos para brevidade
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:http/http.dart' as http;

class EdgeDetector {
  Interpreter? _interpreter;

  Future initModel() async {
    _interpreter = await Interpreter.fromAsset('model.tflite',
         options: InterpreterOptions()..useNNAPIForAndroid = true);
  }

  // preprocess e runInference são funções que redimensionam a imagem e chamam _interpreter!.run(...)
  Future<bool> detectCritical(Uint8List frameBytes) async {
    // retornar true se detectar evento crítico (p.ex. pessoa caída)
    // lógica simples: se detector encontra "person" com alta confiança e pose suspeita
  }
}

class CameraDetectPage extends StatefulWidget {  }

class _CameraDetectPageState extends State<CameraDetectPage> {
  CameraController? controller;
  EdgeDetector detector = EdgeDetector();
  bool sendingEvent = false;

  @override
  void initState() {
    super.initState();
    initCameraAndModel();
  }

  Future initCameraAndModel() async {
    final cameras = await availableCameras();
    controller = CameraController(cameras.first, ResolutionPreset.medium);
    await controller!.initialize();
    await detector.initModel();

    controller!.startImageStream((CameraImage image) async {
      if (sendingEvent) return;
      // pega frame, converte para bytes compatíveis com o modelo
      final detected = await detector.detectCritical(...);
      if (detected) {
        sendingEvent = true;
        await sendEventToBackend({
          "device_id": "phone-001",
          "timestamp": DateTime.now().toIso8601String(),
          "type": "SUSPICIOUS_MOVEMENT",
          "lat": 0.0, "lon": 0.0
        });
        sendingEvent = false;
      }
    });
  }

  Future sendEventToBackend(Map<String,dynamic> event) async {
    final resp = await http.post(Uri.parse('http://SEU_SERVIDOR:3000/api/events'),
        headers: {'Content-Type':'application/json'},
        body: jsonEncode(event));
    // tratar resposta
  }
}
