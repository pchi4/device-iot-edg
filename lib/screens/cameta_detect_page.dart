import 'dart:typed_data';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:collection/collection.dart';

import 'package:device_edg/services/event_service.dart';
import 'package:device_edg/services/tflite_service.dart';

class CameraDetectPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraDetectPage({required this.cameras, Key? key}) : super(key: key);

  @override
  _CameraDetectPageState createState() => _CameraDetectPageState();
}

class _CameraDetectPageState extends State<CameraDetectPage> {
  CameraController? _controller;
  final TfliteService _tfliteService = TfliteService();
  final EventService _eventService = EventService();

  bool _modelLoading = true;
  bool _isCameraInitialized = false;
  bool _sendingEvent = false;
  Interpreter? _interpreter;
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadModel();
  }

  Future<void> _initServices() async {
    await _tfliteService.loadModel('assets/mobilenet_v1_1.0_224.tflite');

    _interpreter = _tfliteService.interpreter; // garante que não seja null

    // carregar labels também
    final rawLabels = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/labels.txt');
    _labels = rawLabels.split('\n');

    if (mounted) {
      setState(() {
        _modelLoading = false;
      });
    }
  }

  Future<void> _loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      if (Platform.isAndroid || Platform.isIOS) {
        options.addDelegate(XNNPackDelegate());
      }

      _interpreter = await Interpreter.fromAsset(
        'models/mobilenet_v1_1.0_224.tflite',
        options: options,
      );

      // Carregar labels
      final rawLabels = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/labels.txt');
      _labels = rawLabels.split('\n');

      setState(() {
        _modelLoading = true;
      });

      print("Modelo carregado com sucesso!");
    } catch (e) {
      print("Erro ao carregar modelo: $e");
    }
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      _showErrorDialog(
        "Nenhuma Câmera",
        "Nenhuma câmera disponível. Verifique as permissões.",
      );
      return;
    }

    if (_controller != null) await _controller!.dispose();

    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      _startStream();
      print("✅ Câmera inicializada e stream iniciada!");
    } on CameraException catch (e) {
      print("❌ Erro ao inicializar a câmera: $e");
      _showErrorDialog(
        "Erro na Câmera",
        "Não foi possível inicializar: ${e.code}",
      );
      _controller = null;
    }
  }

  void _startStream() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_tfliteService.interpreter == null) return;

    _controller!.startImageStream((CameraImage image) async {
      if (_sendingEvent) return;

      // final bool detectedCritical = _stubDetect();

      final bool detectedCritical = await _runModel(image);

      if (detectedCritical) {
        _sendingEvent = true;
        setState(() {});

        await _eventService.sendDetectionEvent('SUSPICIOUS_MOVEMENT');

        _sendingEvent = false;
        setState(() {});
      }
    });
  }

  Future<bool> _runModel(CameraImage image) async {
    if (_interpreter == null) return false;

    final input = _convertCameraImage(image);

    var output = List.filled(1001, 0.0).reshape([1, 1001]);
    _interpreter!.run(input, output);

    // Pega índice da maior probabilidade
    final scores = output[0];
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final maxIndex = scores.indexOf(maxScore);

    final detectedLabel =
        maxIndex < _labels.length ? _labels[maxIndex] : 'desconhecido';

    print("Detectado: $detectedLabel ($maxScore)");
    return detectedLabel.toLowerCase().contains("person");
  }

  img.Image convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final planes = image.planes;

    var imageRgb = img.Image(width: width, height: height);
    return imageRgb;
  }

  List<List<List<List<double>>>> _convertCameraImage(CameraImage image) {
    // final Uint8List bytes = image.planes[0].bytes;
    final img.Image converted = convertYUV420ToImage(image);

    // final img.Image converted = img.Image.fromBytes(
    //   width: image.width,
    //   height: image.height,
    //   bytes: bytes.buffer,
    //   numChannels: 3, // se vier BGRA ou RGBA
    // );

    print("Camera format: ${image.format.group}");

    final resized = img.copyResize(converted, width: 224, height: 224);

    var input = List.generate(
      1,
      (_) => List.generate(
        224,
        (_) => List.generate(224, (_) => List.filled(3, 0.0)),
      ),
    );

    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y); // retorna Pixel

        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }

    return input;
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    // _tfliteService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      final bool modelReady = _tfliteService.interpreter != null;

      return Scaffold(
        appBar: AppBar(title: const Text('Edge Vision MVP')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  modelReady ? Icons.check_circle_outline : Icons.pending,
                  size: 60,
                  color: modelReady ? Colors.greenAccent : Colors.orange,
                ),
                const SizedBox(height: 20),

                Text(
                  _modelLoading
                      ? "Carregando Módulo AI..."
                      : (modelReady
                          ? "SISTEMA PRONTO"
                          : "ERRO: Falha ao carregar Modelo"),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: modelReady ? Colors.greenAccent : Colors.redAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed:
                        modelReady && widget.cameras.isNotEmpty
                            ? _initializeCamera
                            : null,
                    icon: const Icon(Icons.videocam, size: 28),
                    label: const Text(
                      'INICIAR MONITORAMENTO',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                if (widget.cameras.isEmpty && !_modelLoading)
                  const Text(
                    "⚠️ AVISO: Nenhuma câmera detectada. Verifique as permissões.",
                    style: TextStyle(color: Colors.redAccent, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoramento Ativo'),

        actions: [
          TextButton.icon(
            onPressed: () async {
              await _controller?.stopImageStream();
              await _controller?.dispose();
              setState(() {
                _isCameraInitialized = false;
                _controller = null;
              });
            },
            icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
            label: const Text(
              'PARAR',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),

              color:
                  _sendingEvent
                      ? Colors.orange.withOpacity(0.9)
                      : Colors.green.withOpacity(0.8),
              child: Row(
                children: [
                  Icon(
                    _sendingEvent ? Icons.warning : Icons.check_circle,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _sendingEvent
                        ? '!! EVENTO CRÍTICO DETECTADO E ENVIANDO !!'
                        : 'Monitorando com Sucesso. Aguardando Detecções...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
