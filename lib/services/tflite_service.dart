import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';

class TfliteService {
  Interpreter? _interpreter;

  Interpreter? get interpreter => _interpreter;

  Future<bool> loadModel(String assetPath) async {
    try {
      final options = InterpreterOptions()..threads = 4;

      if (Platform.isAndroid || Platform.isIOS) {
        options.addDelegate(XNNPackDelegate());
      }

      _interpreter = await Interpreter.fromAsset(assetPath, options: options);
      print("✅ Modelo carregado com sucesso!");
      return true;
    } catch (e) {
      print("❌ Erro ao carregar modelo: $e");
      _interpreter = null;
      return false;
    }
  }

  void close() {
    _interpreter?.close();
  }
}
