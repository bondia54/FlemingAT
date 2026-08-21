import 'package:flutter/material.dart';

class ConformidadeScreen extends StatefulWidget {
  const ConformidadeScreen({super.key});

  @override
  State<ConformidadeScreen> createState() => _ConformidadeScreenState();
}

class _ConformidadeScreenState extends State<ConformidadeScreen> {
  // MODO DE TESTE — ver termometro_screen.dart para o padrão completo.
  static const bool _usarDadosFalsos = true;

  final int _farmaciasAnvisaReady = 14;
  final int _totalFarmacias = 18;

  double get _percentual => _farmaciasAnvisaReady / _totalFarmacias;

  @override
  Widget build(BuildContext context) {
    final percentualExibido = (_percentual * 100).toStringAsFixed(0);
    final acimaDaMeta = _percentual >= 0.80;

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
            'Conformidade',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: _percentual,
                          strokeWidth: 16,
                          backgroundColor: Colors.grey.shade200,
                          color: acimaDaMeta ? Colors.green : Colors.orange,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$percentualExibido%',
                            style: const TextStyle(
                                fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                          const Text('Anvisa-Ready'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '$_farmaciasAnvisaReady de $_totalFarmacias farmácias em conformidade',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  acimaDaMeta
                      ? 'Acima da meta de 80%'
                      : 'Abaixo da meta de 80% — atenção necessária',
                  style: TextStyle(
                    color: acimaDaMeta ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
