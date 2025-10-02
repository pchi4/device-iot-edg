// lib/pages/main_screen.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:device_edg/screens/cameta_detect_page.dart';
import 'package:device_edg/screens/history_page.dart';

class MainScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MainScreen({required this.cameras, Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Lista de Widgets (páginas) que o BottomNavigationBar irá alternar
    final List<Widget> children = [
      CameraDetectPage(
        cameras: widget.cameras,
      ), // Índice 0: Monitoramento (AI/Câmera)
      const HistoryPage(), // Índice 1: Histórico (Dados/GET)
    ];

    return Scaffold(
      body: children[_currentIndex],
      // Estilo do BottomNavigationBar (em harmonia com o tema escuro)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.teal, // Cor de destaque
        unselectedItemColor: Colors.grey,
        backgroundColor: Theme.of(context).colorScheme.surface, // Fundo escuro
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam_outlined),
            label: 'Monitorar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_toggle_off),
            label: 'Histórico',
          ),
        ],
      ),
    );
  }
}
