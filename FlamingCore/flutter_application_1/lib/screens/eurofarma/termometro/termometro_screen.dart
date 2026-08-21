import 'package:flutter/material.dart';

class TermometroScreen extends StatefulWidget {
  const TermometroScreen({super.key});

  @override
  State<TermometroScreen> createState() => _TermometroScreenState();
}

class _TermometroScreenState extends State<TermometroScreen> {
  // ==========================================================
  // MODO DE TESTE — true enquanto não houver Function real pra
  // essa tela. Quando existir, trocar para false e substituir
  // _carregar() por uma chamada via HttpInterceptor.
  // ==========================================================
  static const bool _usarDadosFalsos = true;

  static const String _nomeEurofarma = 'Eurofarma';

  final List<Map<String, dynamic>> _fabricantes = [
    {'nome': 'Eurofarma', 'score_medio': 78.4, 'giro_dias': 22, 'lotes': 340},
    {'nome': 'EMS', 'score_medio': 71.2, 'giro_dias': 26, 'lotes': 298},
    {'nome': 'Medley', 'score_medio': 65.9, 'giro_dias': 31, 'lotes': 210},
    {'nome': 'Neo Química', 'score_medio': 58.3, 'giro_dias': 38, 'lotes': 175},
    {'nome': 'Cimed', 'score_medio': 52.1, 'giro_dias': 44, 'lotes': 132},
  ];

  double get _mediaGeral {
    final soma =
        _fabricantes.fold<double>(0, (s, f) => s + (f['score_medio'] as num));
    return soma / _fabricantes.length;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_usarDadosFalsos)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 16),
              color: Colors.amber.shade100,
              child: const Text(
                'Modo de teste — dados fictícios',
                style: TextStyle(fontSize: 12),
              ),
            ),
          const Text(
            'Termômetro de Giro',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Média geral da rede: ${_mediaGeral.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Fabricante')),
                  DataColumn(label: Text('Score Médio')),
                  DataColumn(label: Text('Giro (dias)')),
                  DataColumn(label: Text('Lotes')),
                ],
                rows: _fabricantes.map((f) {
                  final ehEurofarma = f['nome'] == _nomeEurofarma;
                  return DataRow(
                    color: ehEurofarma
                        ? MaterialStateProperty.all(Colors.green.shade50)
                        : null,
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            if (ehEurofarma)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.star,
                                    size: 16, color: Colors.green),
                              ),
                            Text(
                              f['nome'],
                              style: TextStyle(
                                fontWeight: ehEurofarma
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text('${f['score_medio']}')),
                      DataCell(Text('${f['giro_dias']} dias')),
                      DataCell(Text('${f['lotes']}')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
