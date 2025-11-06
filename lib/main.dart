import 'package:flutter/material.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:device_edg/services/event_service.dart';
import 'package:device_edg/screens/cameta_detect_page.dart';
import 'package:device_edg/screens/main_screen.dart';
import 'package:camera/camera.dart';

Future<void> backgroundFetchHeadlessTask(HeadlessTask task) async {
  print('[BackgroundFetch] Headless event received.');

  final eventService = EventService();
  await eventService.syncOfflineEvents();

  BackgroundFetch.finish(task.taskId);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);

  List<CameraDescription> cameras = [];

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Erro ao obter câmeras: $e');
  }

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initBackgroundFetch();
  }

  Future<void> initBackgroundFetch() async {
    try {
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,
          stopOnTerminate: false,
          enableHeadless: true,
          startOnBoot: true,
          requiresCharging: false,
          requiredNetworkType: NetworkType.ANY,
        ),
        (String taskId) async {
          print('[BackgroundFetch] Evento recebido: $taskId');
          final eventService = EventService();
          await eventService.syncOfflineEvents();
          BackgroundFetch.finish(taskId);
        },
        (String taskId) async {
          print('[BackgroundFetch] TIMEOUT: $taskId');
          BackgroundFetch.finish(taskId);
        },
      );

      print('✅ BackgroundFetch configurado com sucesso!');
    } catch (e) {
      print('❌ Erro ao configurar BackgroundFetch: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edge Vision MVP',
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
      home: MainScreen(cameras: widget.cameras),
    );
  }
}
