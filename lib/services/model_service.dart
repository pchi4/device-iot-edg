import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  Interpreter? interpreter;
  List<int> inputShape = [1, 224, 224, 3]; // Default shape for MobileNet V1

  // Singleton Pattern
  static final ModelService _instance = ModelService._internal();
  factory ModelService() => _instance;
  ModelService._internal();

  Future<void> loadModel() async {
    try {
      // Carrega o modelo quantizado (uint8)
      interpreter = await Interpreter.fromAsset(
        'assets/mobilenet_v1_1.0_224.tflite',
        options: InterpreterOptions()..threads = 2,
      );

      // Ajusta o inputShape baseado no modelo carregado
      final inputTensor = interpreter!.getInputTensor(0);
      inputShape = inputTensor.shape;

      print(
        '✅ Modelo ${inputTensor.type} carregado com sucesso (${interpreter!.path})! Shape: $inputShape',
      );
    } catch (e) {
      print('🛑 Falha ao carregar o modelo TFLite: $e');
      throw Exception('Falha ao carregar o modelo.');
    }
  }

  void dispose() {
    interpreter?.close();
    print("🛑 Modelo TFLite fechado.");
  }
}
