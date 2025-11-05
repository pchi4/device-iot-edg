import 'package:flutter/material.dart';
// Import CORRETO
import 'package:background_fetch/background_fetch.dart';

// Certifique-se de que esses arquivos estão no caminho correto
import 'package:device_edg/services/event_service.dart';
import 'package:device_edg/screens/cameta_detect_page.dart';
import 'package:device_edg/screens/main_screen.dart';
import 'package:camera/camera.dart';

// Não precisamos mais de uma variável global para as câmeras
// List<CameraDescription> availableCamerasList = []; // REMOVIDO/TRANSFERIDO

// Função Headless Task permanece inalterada
Future<void> backgroundFetchHeadlessTask(HeadlessTask task) async {
  print('[BackgroundFetch] Headless event received.');

  final eventService = EventService();
  await eventService.syncOfflineEvents();

  BackgroundFetch.finish(task.taskId);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. CHAVE: REGISTRAR A HEADLESS TASK ANTES DE runApp()
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);

  List<CameraDescription> cameras =
      []; // Variável local para armazenar as câmeras

  try {
    // Tenta obter a lista de câmeras
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Erro ao obter câmeras: $e');
  }

  // 2. CHAMA O runApp() PASSANDO A LISTA DE CÂMERAS
  runApp(MyApp(cameras: cameras));
}

// MyApp agora é StatelessWidget para receber as câmeras e iniciar o Background Fetch
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

  // late final List<CameraDescription> cameras; // REMOVIDO (Dados vêm do widget.cameras)

  Future<void> initBackgroundFetch() async {
    try {
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15, // intervalo em minutos
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
      // O 'home' AGORA APONTA PARA O NOSSO GERENCIADOR DE ABAS, USANDO AS CÂMERAS PASSADAS
      home: MainScreen(
        cameras: widget.cameras,
      ), // Acessa a propriedade 'cameras' do State
    );
  }
}
