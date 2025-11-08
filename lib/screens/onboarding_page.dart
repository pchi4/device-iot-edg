import 'package:flutter/material.dart';

class OnboardingContent {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

final List<OnboardingContent> contents = [
  OnboardingContent(
    title: "Monitoramento Inteligente de Risco",
    description:
        "Nossa IA no dispositivo (Edge AI) detecta anomalias em tempo real, garantindo segurança sem depender da nuvem.",
    icon: Icons.security,
    color: Colors.green.shade800,
  ),
  OnboardingContent(
    title: "Resposta Imediata e Localização",
    description:
        "Eventos críticos são consolidados e notificados instantaneamente, com localização GPS precisa para ação rápida.",
    icon: Icons.location_on,
    color: Colors.orange.shade800,
  ),
  OnboardingContent(
    title: "Otimização de Performance e Bateria",
    description:
        "Utilizamos Isolates e Throttling para processar imagens em segundo plano, mantendo o app rápido e eficiente no uso de bateria.",
    icon: Icons.flash_on,
    color: Colors.blue.shade800,
  ),
];

class OnboardingSlide extends StatelessWidget {
  final OnboardingContent content;

  const OnboardingSlide({required this.content, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(content.icon, size: 100, color: content.color),
          const SizedBox(height: 50),

          Text(
            content.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: content.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          Text(
            content.description,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingPage({required this.onFinish, super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: contents.length,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (_, i) {
                  return OnboardingSlide(content: contents[i]);
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                contents.length,
                (index) => buildDot(index, context),
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      widget.onFinish();
                    },
                    child: Text(
                      _currentPage == contents.length - 1 ? '' : 'Pular',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == contents.length - 1) {
                          widget.onFinish();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeIn,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: contents[_currentPage].color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                      ),
                      child: Text(
                        _currentPage == contents.length - 1
                            ? 'INICIAR'
                            : 'PRÓXIMO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Container buildDot(int index, BuildContext context) {
    return Container(
      height: 10,
      width: _currentPage == index ? 25 : 10,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _currentPage == index
            ? contents[_currentPage].color
            : Colors.grey,
      ),
    );
  }
}
