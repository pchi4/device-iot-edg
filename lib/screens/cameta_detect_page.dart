// lib/pages/camera_detect_page.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    // Carrega o modelo TFLite na inicialização
    await _tfliteService.loadModel('assets/mobilenet_v1_1.0_224.tflite');
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

      // 1. **INFERÊNCIA DA IMAGEM**
      // TODO: Usar _tfliteService.interpreter para processar a 'image'

      // 2. **SIMULAÇÃO/DETECÇÃO**
      final bool detectedCritical = _stubDetect(); // Simulação

      if (detectedCritical) {
        _sendingEvent = true;
        setState(() {}); // Atualiza o status na tela

        await _eventService.sendDetectionEvent('SUSPICIOUS_MOVEMENT');

        _sendingEvent = false;
        setState(() {}); // Atualiza o status na tela
      }
    });
  }

  bool _stubDetect() {
    final now = DateTime.now().millisecond;
    return now % 1000 < 50;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ESTADO 1: Tela de Carregamento/Ação Inicial
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
                // Ícone Grande
                Icon(
                  modelReady ? Icons.check_circle_outline : Icons.pending,
                  size: 60,
                  color: modelReady ? Colors.greenAccent : Colors.orange,
                ),
                const SizedBox(height: 20),

                // Indicador de Status do Modelo
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

                // NOVO BOTÃO DE AÇÃO
                SizedBox(
                  width: double.infinity, // Ocupa a largura total
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

                // Feedback de Erro/Aviso (Câmera)
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

    // ESTADO 2: Tela de Visualização da Câmera Ativa
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoramento Ativo'),
        // Botão de Parada mais visível
        actions: [
          TextButton.icon(
            onPressed: () async {
              // Lógica para parar e resetar o estado
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
          // 1. VISUALIZAÇÃO DA CÂMERA (Fundo)
          Positioned.fill(child: CameraPreview(_controller!)),

          // 2. STATUS DE DETECÇÃO (Sobreposição)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              // Cor de fundo muda conforme o status (verde para normal, laranja para envio)
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
