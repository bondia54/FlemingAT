import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/http_interceptor.dart';

class DashboardEurofarmaScreen extends StatefulWidget {
  final Function(String)? onNavegar;

  const DashboardEurofarmaScreen({super.key, this.onNavegar});

  @override
  State<DashboardEurofarmaScreen> createState() =>
      _DashboardEurofarmaScreenState();
}

class _DashboardEurofarmaScreenState extends State<DashboardEurofarmaScreen> {
  // ==========================================================
  // MODO DE TESTE — true enquanto a Function
  // buscar_dashboard_eurofarma não estiver deployada.
  // Quando a Laysla/Samuel liberarem, trocar para false
  // (ou remover esse bloco todo).
  // ==========================================================
  static const bool _usarDadosFalsos = true;

  Map<String, dynamic>? _dados;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  static final Map<String, dynamic> _dadosFalsos = {
    'total_desperdicio_evitado': '128.450,00',
    'total_medicamentos_preservados': '3.240',
    'ivf_medio': '0.82',
    'farmacias_anvisa_ready': 14,
    'total_farmacias': 18,
  };

  Future<void> _carregar() async {
    if (_usarDadosFalsos) {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _dados = _dadosFalsos;
        _carregando = false;
      });
      return;
    }

    // ======================================================
    // TODO — QUANDO TIVER A FUNCTION: descomentar e apagar o
    // bloco "if (_usarDadosFalsos)" acima.
    // ======================================================
    try {
      final response =
          await HttpInterceptor.get('/buscar_dashboard_eurofarma');
      setState(() => _dados = json.decode(response.body));
    } catch (e) {
      setState(() => _dados = null);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_dados == null) {
      return const Center(child: Text('Erro ao carregar.'));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_usarDadosFalsos)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 16),
              color: Colors.amber.shade100,
              child: const Text(
                'Modo de teste — mostrando dados fictícios (Function ainda não deployada)',
                style: TextStyle(fontSize: 12),
              ),
            ),
          const Text(
            'Dashboard Eurofarma',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // 4 cards de acesso rápido
          Row(
            children: [
              _card('Termômetro de Giro', Icons.bar_chart, 'termometro'),
              _card('Vulnerabilidade IVF', Icons.warning, 'vulnerabilidade'),
              _card('Impacto Social', Icons.people, 'impacto_social'),
              _card('Conformidade', Icons.verified, 'conformidade'),
            ],
          ),
          const SizedBox(height: 24),
          // Dados agregados — sem identificar farmácia individual
          Text(
              'Desperdício evitado total: R\$ ${_dados!['total_desperdicio_evitado']}'),
          Text(
              'Medicamentos preservados: ${_dados!['total_medicamentos_preservados']}'),
          Text('IVF médio da rede: ${_dados!['ivf_medio']}'),
          Text(
              'Farmácias Anvisa-Ready: ${_dados!['farmacias_anvisa_ready']} de ${_dados!['total_farmacias']}'),
        ],
      ),
    );
  }

  Widget _card(String titulo, IconData icone, String destino) {
    return Expanded(
      child: Card(
        child: InkWell(
          onTap: () => widget.onNavegar?.call(destino),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icone, size: 32),
                const SizedBox(height: 8),
                Text(titulo, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
