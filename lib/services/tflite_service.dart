import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:io';

enum ModelTier { standard, lite }

class TfliteService {
  Interpreter? _interpreter;
  ModelTier _activeTier = ModelTier.standard;
  final Battery _battery = Battery();

  static const String _standardModelPath = 'assets/mobilenet_v1_1.0_224.tflite';
  static const String _liteModelPath = 'assets/mobilenet_lite.tflite';

  Interpreter? get interpreter => _interpreter;
  ModelTier get activeTier => _activeTier;

  Future<void> initialize() async {
    await _loadModel(_standardModelPath, ModelTier.standard);

    _startResourceMonitoring();
  }

  Future<void> _loadModel(String path, ModelTier tier) async {
    try {
      _interpreter?.close();
      _interpreter = null;

      final options = InterpreterOptions()..threads = 4;
      // if (Platform.isAndroid || Platform.isIOS) {
      //   options.addDelegate(XNNPackDelegate());
      // }

      _interpreter = await Interpreter.fromAsset(path, options: options);
      _activeTier = tier;
      print("✅ Modelo $tier carregado com sucesso ($path)!");
    } catch (e) {
      print("❌ Erro ao carregar modelo ($path): $e");
      _interpreter = null;
    }
  }

  void _startResourceMonitoring() {
    _battery.onBatteryStateChanged.listen((BatteryState state) async {
      final isUnpluggedAndLow =
          state == BatteryState.discharging && await _isBatteryLow();

      if (isUnpluggedAndLow && _activeTier == ModelTier.standard) {
        await _swapModel(ModelTier.lite);
      } else if (state == BatteryState.charging &&
          _activeTier == ModelTier.lite) {
        await _swapModel(ModelTier.standard);
      }
    });
  }

  Future<bool> _isBatteryLow() async {
    final level = await _battery.batteryLevel;
    return level <= 20;
  }

  Future<void> _swapModel(ModelTier targetTier) async {
    if (_activeTier == targetTier) {
      return;
    }

    print(
      "🔄 Iniciando troca de modelo: ${_activeTier.name} -> ${targetTier.name}",
    );

    String path = (targetTier == ModelTier.standard)
        ? _standardModelPath
        : _liteModelPath;
    await _loadModel(path, targetTier);
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
