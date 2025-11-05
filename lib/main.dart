// import 'package:camera/camera.dart';
// import 'package:device_edg/screens/main_screen.dart';
// import 'package:flutter/material.dart';

// List<CameraDescription> availableCamerasList = [];

// Future<void> main() async {
//   // Garante que os WidgetsBinding estão inicializados antes de chamar métodos nativos
//   WidgetsFlutterBinding.ensureInitialized();

//   try {
//     // Tenta obter a lista de câmeras
//     availableCamerasList = await availableCameras();
//   } on CameraException catch (e) {
//     print('Erro ao obter câmeras: $e');
//   }

//   // Passa a lista de câmeras para o MyApp
//   runApp(MyApp(cameras: availableCamerasList));
// }

// class MyApp extends StatelessWidget {
//   final List<CameraDescription> cameras;
//   const MyApp({required this.cameras, Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Edge Vision MVP',
//       // TEMA DEFINIDO AQUI (configuração global)
//       theme: ThemeData(
//         brightness: Brightness.dark,
//         primaryColor: Colors.teal,
//         colorScheme: ColorScheme.dark(
//           primary: Colors.teal,
//           secondary: Colors.redAccent,
//           surface: Colors.grey[900]!,
//         ),
//         appBarTheme: AppBarTheme(
//           backgroundColor: Colors.grey[900],
//           elevation: 0,
//         ),
//         elevatedButtonTheme: ElevatedButtonThemeData(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.teal,
//             foregroundColor: Colors.white,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//         ),
//       ),
//       // O 'home' AGORA APONTA PARA O NOSSO GERENCIADOR DE ABAS
//       home: MainScreen(cameras: cameras),
//     );
//   }
// }

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:device_edg/services/event_service.dart';
import 'package:device_edg/screens/cameta_detect_page.dart';
import 'package:device_edg/screens/main_screen.dart';
import 'package:camera/camera.dart';

List<CameraDescription> availableCamerasList = [];

Future<void> backgroundFetchHeadlessTask(HeadlessTask task) async {
  print('[BackgroundFetch] Headless event received.');

  final eventService = EventService();
  await eventService.syncOfflineEvents();

  BackgroundFetch.finish(task.taskId);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Tenta obter a lista de câmeras
    availableCamerasList = await availableCameras();
  } on CameraException catch (e) {
    print('Erro ao obter câmeras: $e');
  }
  runApp(const MyApp());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initBackgroundFetch();
  }

  late final List<CameraDescription> cameras;

  Future<void> initBackgroundFetch() async {
    BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15, // em minutos
        stopOnTerminate: false,
        enableHeadless: true,
        startOnBoot: true,
        requiresCharging: false,
        requiredNetworkType: NetworkType.ANY,
      ),
      (String taskId) async {
        print('[BackgroundFetch] Event received: $taskId');

        final eventService = EventService();
        await eventService.syncOfflineEvents();

        BackgroundFetch.finish(taskId);
      },
      (String taskId) async {
        print('[BackgroundFetch] TIMEOUT: $taskId');
        BackgroundFetch.finish(taskId);
      },
    );
  }

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
