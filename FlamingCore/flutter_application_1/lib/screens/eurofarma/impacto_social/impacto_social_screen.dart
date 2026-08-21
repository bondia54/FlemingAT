import 'package:flutter/material.dart';

class ImpactoSocialScreen extends StatefulWidget {
  const ImpactoSocialScreen({super.key});

  @override
  State<ImpactoSocialScreen> createState() => _ImpactoSocialScreenState();
}

class _ImpactoSocialScreenState extends State<ImpactoSocialScreen> {
  // MODO DE TESTE — ver termometro_screen.dart para o padrão completo.
  static const bool _usarDadosFalsos = true;

  final Map<String, dynamic> _dados = {
    'desperdicio_evitado': '128.450,00',
    'medicamentos_preservados': '3.240',
    'populacao_atendida': '18.500',
  };

  final List<Map<String, dynamic>> _evolucaoMensal = [
    {'mes': 'Mar', 'valor': 62},
    {'mes': 'Abr', 'valor': 70},
    {'mes': 'Mai', 'valor': 75},
    {'mes': 'Jun', 'valor': 88},
    {'mes': 'Jul', 'valor': 95},
  ];

  Widget _cardResumo(String titulo, String valor, IconData icone) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icone, size: 28, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                valor,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxValor = _evolucaoMensal
        .map((e) => e['valor'] as int)
        .reduce((a, b) => a > b ? a : b);

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
            'Impacto Social',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _cardResumo('Desperdício evitado (R\$)',
                  _dados['desperdicio_evitado'], Icons.savings),
              const SizedBox(width: 16),
              _cardResumo('Medicamentos preservados',
                  _dados['medicamentos_preservados'], Icons.medication),
              const SizedBox(width: 16),
              _cardResumo('População atendida',
                  _dados['populacao_atendida'], Icons.people),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Evolução Mensal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _evolucaoMensal.map((e) {
                final altura = (e['valor'] as int) / maxValor;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${e['valor']}',
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        FractionallySizedBox(
                          heightFactor: altura,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(e['mes']),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
