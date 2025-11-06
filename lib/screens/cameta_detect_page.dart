import 'dart:typed_data';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:collection/collection.dart';
import 'package:battery_plus/battery_plus.dart'; // Necessário para BatteryState

import 'package:device_edg/services/event_service.dart';
import 'package:device_edg/services/tflite_service.dart';
import 'package:device_edg/models/risk_event.dart';
import 'package:device_edg/services/risk_consolidation_service.dart';
import 'package:device_edg/services/device_health_service.dart';

extension RectExtension on Rect {
  Rect normalize() {
    return Rect.fromLTRB(
      left < right ? left : right,
      top < bottom ? top : bottom,
      left < right ? right : left,
      top < bottom ? bottom : top,
    );
  }
}

class RoiPainter extends CustomPainter {
  final Offset? startPoint;
  final Offset? endPoint;
  final Rect roiRect;

  RoiPainter({this.startPoint, this.endPoint, required this.roiRect});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Cor da área escura (Overlay)
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    // 2. Cor da borda
    final borderPaint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // 3. Cor da área de seleção (interior)
    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Desenhar o overlay escuro em toda a área
    canvas.drawRect(Offset.zero & size, overlayPaint);

    // Calcular o retângulo selecionado (em pixels da tela)
    final rect = Rect.fromPoints(
      startPoint ?? Offset.zero,
      endPoint ?? Offset.zero,
    ).normalize();

    // Desenhar o retângulo de seleção preenchido e com borda
    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, borderPaint);

    // Reverter o overlay escuro apenas dentro do retângulo selecionado
    canvas.drawRect(rect, Paint()..blendMode = BlendMode.clear);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
// Fim da classe RoiPainter

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
  final RiskConsolidationService _riskConsolidator = RiskConsolidationService();
  final DeviceHealthService _healthService = DeviceHealthService(); // NOVO

  bool _modelLoading = true;
  bool _isCameraInitialized = false;
  bool _sendingEvent = false;
  Interpreter? _interpreter;
  List<String> _labels = [];

  // --- Lógica de ROI ---
  Rect _roi = const Rect.fromLTWH(
    0.0,
    0.0,
    1.0,
    1.0,
  ); // Padrão: Imagem inteira (0.0 a 1.0)
  bool _isEditingRoi = false;
  Offset? _startDrag;
  Offset? _endDrag;
  // --------------------

  @override
  void initState() {
    super.initState();
    _initServices();

    _riskConsolidator.onRiskUpdated = () {
      if (mounted) {
        setState(() {});
      }
    };

    // Inicializa o monitoramento de saúde e subscreve o callback
    _healthService.startMonitoring();
    _healthService.setUpdateListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _initServices() async {
    await _tfliteService.initialize();

    _interpreter = _tfliteService.interpreter;

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
      await _runModelAndConsolidateRisk(image);
    });
  }

  Future<void> _runModelAndConsolidateRisk(CameraImage image) async {
    if (_interpreter == null) return;

    final input = _convertCameraImage(image);

    var output = List.filled(1001, 0.0).reshape([1, 1001]);
    _tfliteService.interpreter!.run(input, output);

    final scores = output[0] as List<double>;
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final maxIndex = scores.indexOf(maxScore);

    final detectedLabel = maxIndex < _labels.length
        ? _labels[maxIndex]
        : 'desconhecido';

    double baseRisk = 0;
    String analysisType = detectedLabel;

    if (detectedLabel.toLowerCase().contains("person")) {
      baseRisk = 60;
      analysisType = 'Pessoa Detectada';
    } else if (detectedLabel.toLowerCase().contains("weapon") ||
        detectedLabel.toLowerCase().contains("knife")) {
      baseRisk = 90;
      analysisType = 'Objeto Perigoso Detectado';
    } else if (maxScore > 0.8) {
      baseRisk = 40;
    }

    double currentRiskScore = baseRisk * maxScore;
    currentRiskScore = currentRiskScore.clamp(0.0, 100.0);

    if (currentRiskScore >= 30.0) {
      final riskEvent = RiskEvent(
        timestamp: DateTime.now(),
        detectionType: analysisType,
        confidence: maxScore,
        riskScore: currentRiskScore,
      );

      _riskConsolidator.addEvent(riskEvent);
    }
  }

  // NOTE: Essa função ainda precisa de uma implementação YUV420 estável para rodar.
  img.Image convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    var imageRgb = img.Image(width: width, height: height);
    return imageRgb;
  }

  List<List<List<List<double>>>> _convertCameraImage(CameraImage image) {
    img.Image converted = convertYUV420ToImage(image);

    // =======================================================
    // 💡 LÓGICA DE RECORTE (CROP) DA ROI
    // =======================================================
    final int x = (_roi.left * converted.width).round();
    final int y = (_roi.top * converted.height).round();
    final int width = (_roi.width * converted.width).round();
    final int height = (_roi.height * converted.height).round();

    final int cropWidth = width.clamp(1, converted.width - x);
    final int cropHeight = height.clamp(1, converted.height - y);

    img.Image roiImage;

    try {
      roiImage = img.copyCrop(
        converted,
        x: x,
        y: y,
        width: cropWidth,
        height: cropHeight,
      );
    } catch (e) {
      print('❌ Erro de recorte (ROI inválida?): $e');
      roiImage = converted;
    }

    final resized = img.copyResize(roiImage, width: 224, height: 224);
    // =======================================================
    // FIM DA LÓGICA DE ROI
    // =======================================================

    var input = List.generate(
      1,
      (_) => List.generate(
        224,
        (_) => List.generate(224, (_) => List.filled(3, 0.0)),
      ),
    );

    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y);

        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }

    return input;
  }

  // --- Lógica de Feedback (Self-Correction) ---
  Future<void> _showFeedbackDialog() async {
    final String lastDetectedLabel = "Pessoa Detectada";
    final double lastConfidence = 0.75;
    String? correctionLabel;

    correctionLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Correção de Anomalia (Self-Correction)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modelo detectou: **$lastDetectedLabel** (Confiança: ${lastConfidence * 100}%)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text('O que era o objeto REALMENTE?'),

              ...[
                    'Falso Positivo (Nada)',
                    'Outro Objeto',
                    'Era o que o Modelo disse (Confirmação)',
                  ]
                  .map(
                    (label) => RadioListTile<String>(
                      title: Text(label),
                      value: label,
                      groupValue: correctionLabel,
                      onChanged: (value) {
                        Navigator.of(ctx).pop(value);
                      },
                    ),
                  )
                  .toList(),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (correctionLabel != null) {
      await _eventService.sendFeedbackEvent(
        userCorrection: correctionLabel,
        detectedLabel: lastDetectedLabel,
        confidence: lastConfidence,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Feedback de correção enviado: $correctionLabel'),
        ),
      );
    }
  }

  // --- Lógica de ROI UI ---
  Widget _buildRoiOverlay(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onPanDown: (details) {
          setState(() {
            _startDrag = details.localPosition;
            _endDrag = details.localPosition;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _endDrag = details.localPosition;
          });
        },
        child: CustomPaint(
          painter: RoiPainter(
            startPoint: _startDrag,
            endPoint: _endDrag,
            roiRect: _roi,
          ),
        ),
      ),
    );
  }

  void _saveRoi() {
    if (_startDrag == null || _endDrag == null || context.size == null) {
      _roi = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
    } else {
      final width = context.size!.width;
      final height = context.size!.height;

      final Rect normalizedRoi = Rect.fromPoints(
        _startDrag!,
        _endDrag!,
      ).normalize();

      _roi = Rect.fromLTWH(
        (normalizedRoi.left / width).clamp(0.0, 1.0),
        (normalizedRoi.top / height).clamp(0.0, 1.0),
        (normalizedRoi.width / width).clamp(0.0, 1.0),
        (normalizedRoi.height / height).clamp(0.0, 1.0),
      );

      print('✅ Nova ROI definida: $_roi');
    }

    _controller?.startImageStream((image) async {
      if (_sendingEvent) return;
      await _runModelAndConsolidateRisk(image);
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
    _tfliteService.close();
    _riskConsolidator.onRiskUpdated = null;
    _healthService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized ||
        _controller == null ||
        _controller!.value.isInitialized == false) {
      final bool modelReady = _tfliteService.interpreter != null;

      // ... (Seu código da tela de inicialização)
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
                    onPressed: modelReady && widget.cameras.isNotEmpty
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
        title: Text(
          _isEditingRoi
              ? 'Definir Região de Interesse (ROI)'
              : 'Monitoramento Ativo',
        ),

        actions: [
          // Botão ROI
          IconButton(
            icon: Icon(
              Icons.zoom_out_map,
              color: _isEditingRoi ? Colors.yellowAccent : Colors.white,
            ),
            tooltip: 'Ajustar Região de Interesse (ROI)',
            onPressed: () {
              setState(() {
                _isEditingRoi = !_isEditingRoi;
                if (!_isEditingRoi) {
                  _saveRoi(); // Salva ROI e reinicia o stream
                } else {
                  _controller?.stopImageStream(); // Pausa o stream para editar
                  _startDrag = null;
                  _endDrag = null;
                }
              });
            },
          ),

          // Botão Feedback
          IconButton(
            icon: const Icon(Icons.rate_review, color: Colors.yellow),
            tooltip: 'Enviar Feedback/Correção',
            onPressed: _showFeedbackDialog,
          ),

          // Botão PARAR
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

          // 1. Status do Modelo e Risco Consolidado
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              color: Colors.black.withOpacity(0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AI Modelo: ${_tfliteService.activeTier.name.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _tfliteService.activeTier.name == 'standard'
                          ? Colors.tealAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                  Text(
                    'Risco Consolidado: ${_riskConsolidator.lastCumulativeRisk.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          // 2. Status de Saúde do Dispositivo
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              color: Colors.black.withOpacity(0.4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CPU: ${_healthService.cpuStatus} (${(_healthService.lastCpuLoad * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Row(
                    children: [
                      Icon(
                        _healthService.batteryState == BatteryState.charging
                            ? Icons.battery_charging_full
                            : Icons.battery_full,
                        color: _healthService.batteryLevel < 25
                            ? Colors.redAccent
                            : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_healthService.batteryLevel}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Overlay de Seleção da ROI
          if (_isEditingRoi) _buildRoiOverlay(context),

          // 4. Notificação de Evento (Bottom Bar)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),

              color: _sendingEvent
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
