// lib/pages/history_page.dart

import 'package:flutter/material.dart';
import 'package:device_edg/services/event_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final EventService _eventService = EventService();
  List<dynamic> _anomalies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnomalies();
  }

  Future<void> _fetchAnomalies() async {
    setState(() {
      _isLoading = true;
    });

    final data = await _eventService.fetchAnomalies();

    if (mounted) {
      setState(() {
        _anomalies = data;
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp).toLocal();
      return '${dateTime.hour}:${dateTime.minute}:${dateTime.second} - ${dateTime.day}/${dateTime.month}';
    } catch (_) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Anomalias'),
        backgroundColor: surfaceColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAnomalies,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _anomalies.isEmpty
          ? const Center(
              child: Text(
                'Nenhuma anomalia salva no banco de dados.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchAnomalies, // Permite puxar para recarregar
              color: Colors.teal,
              child: ListView.builder(
                itemCount: _anomalies.length,
                itemBuilder: (context, index) {
                  final anomaly = _anomalies[index];

                  // 🚨 CORREÇÃO PRINCIPAL: Verificação de Nulo
                  // Garante que 'anomaly' não é nulo antes de tentar acessá-lo.
                  if (anomaly == null) {
                    return const SizedBox.shrink(); // Ou um widget de erro
                  }

                  return Card(
                    // ... (restante do Card)
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber,
                        color: Colors.redAccent,
                        size: 30,
                      ),

                      // Use ?? '' para garantir que, se a chave não existir ou for nula, uma string vazia seja usada.
                      title: Text(
                        anomaly['type']?.toUpperCase() ??
                            'ANOMALIA DESCONHECIDA',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      subtitle: Text(
                        // Use ?? 'N/D' para as coordenadas e verifique se o valor é válido antes de formatar.
                        'Hora: ${_formatTimestamp(anomaly['timestamp'] ?? 'N/A')} | Lat/Lon: ${anomaly['latitude'] != null ? anomaly['latitude'].toStringAsFixed(3) : 'N/D'}, ${anomaly['longitude'] != null ? anomaly['longitude'].toStringAsFixed(3) : 'N/D'}',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
