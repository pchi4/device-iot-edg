import 'package:camera/camera.dart';
import 'package:device_edg/screens/main_screen.dart';
import 'package:flutter/material.dart';

List<CameraDescription> availableCamerasList = [];

Future<void> main() async {
  // Garante que os WidgetsBinding estão inicializados antes de chamar métodos nativos
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Tenta obter a lista de câmeras
    availableCamerasList = await availableCameras();
  } on CameraException catch (e) {
    print('Erro ao obter câmeras: $e');
  }

  // Passa a lista de câmeras para o MyApp
  runApp(MyApp(cameras: availableCamerasList));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({required this.cameras, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edge Vision MVP',
      // TEMA DEFINIDO AQUI (configuração global)
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.teal,
        colorScheme: ColorScheme.dark(
          primary: Colors.teal,
          secondary: Colors.redAccent,
          surface: Colors.grey[900]!,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      // O 'home' AGORA APONTA PARA O NOSSO GERENCIADOR DE ABAS
      home: MainScreen(cameras: cameras),
    );
  }
}
