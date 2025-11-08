import 'package:device_edg/screens/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:device_edg/services/event_service.dart';
import 'package:device_edg/screens/main_screen.dart'; // Mantive MainScreen, assumindo que cameta_detect_page não é a tela final
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> backgroundFetchHeadlessTask(HeadlessTask task) async {
  final eventService = EventService();
  await eventService.syncOfflineEvents();
  BackgroundFetch.finish(task.taskId);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  List<CameraDescription> cameras = [];

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Erro ao obter câmeras: $e');
  }

  runApp(MyApp(cameras: cameras, hasSeenOnboarding: hasSeenOnboarding));
}

class MyApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool hasSeenOnboarding;

  const MyApp({
    Key? key,
    required this.cameras,
    required this.hasSeenOnboarding,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _onboardingCompleted;
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _onboardingCompleted = widget.hasSeenOnboarding;
    _initializationFuture = initBackgroundFetch();
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    setState(() {
      _onboardingCompleted = true;
    });
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
      print('BackgroundFetch configurado com sucesso!');
    } catch (e) {
      print('Erro ao configurar BackgroundFetch: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

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
          home: _onboardingCompleted
              ? MainScreen(cameras: widget.cameras)
              : OnboardingPage(onFinish: _finishOnboarding),
        );
      },
    );
  }
}
