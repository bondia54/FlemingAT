import 'package:flutter/material.dart';

class VulnerabilidadeScreen extends StatefulWidget {
  const VulnerabilidadeScreen({super.key});

  @override
  State<VulnerabilidadeScreen> createState() => _VulnerabilidadeScreenState();
}

class _VulnerabilidadeScreenState extends State<VulnerabilidadeScreen> {
  // MODO DE TESTE — ver termometro_screen.dart para o padrão completo.
  static const bool _usarDadosFalsos = true;

  final List<Map<String, dynamic>> _regioes = [
    {
      'nome': 'Sudeste',
      'ivf_medio': 0.62,
      'incidencia_regional': 0.55,
      'disponibilidade': 0.80,
      'risco_vencimento': 0.40,
    },
    {
      'nome': 'Nordeste',
      'ivf_medio': 0.71,
      'incidencia_regional': 0.68,
      'disponibilidade': 0.60,
      'risco_vencimento': 0.55,
    },
    {
      'nome': 'Sul',
      'ivf_medio': 0.48,
      'incidencia_regional': 0.42,
      'disponibilidade': 0.85,
      'risco_vencimento': 0.30,
    },
  ];

  Widget _barraFator(String label, double valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: valor,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                color: valor >= 0.66
                    ? Colors.red
                    : valor >= 0.4
                        ? Colors.orange
                        : Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(valor * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
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
            'Vulnerabilidade Farmacêutica (IVF) por Região',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: _regioes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final r = _regioes[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              r['nome'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'IVF médio: ${r['ivf_medio']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _barraFator(
                            'Incidência regional', r['incidencia_regional']),
                        _barraFator('Disponibilidade', r['disponibilidade']),
                        _barraFator(
                            'Risco de vencimento', r['risco_vencimento']),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
