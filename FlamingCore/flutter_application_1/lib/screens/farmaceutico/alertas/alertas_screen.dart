import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/http_interceptor.dart';

class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  // ==========================================================
  // MODO DE TESTE — true enquanto o Firebase Realtime Database
  // não estiver disponível. Quando o Josué liberar o acesso,
  // trocar para false (ou remover esse bloco todo).
  // ==========================================================
  static const bool _usarDadosFalsos = true;

  List<Map<String, dynamic>> _alertas = [];

  @override
  void initState() {
    super.initState();

    if (_usarDadosFalsos) {
      _alertas = _dadosFalsos;
    }

    // ======================================================
    // TODO — QUANDO TIVER FIREBASE: descomentar o bloco abaixo
    // e apagar o "if (_usarDadosFalsos)" acima.
    //
    // import 'package:firebase_auth/firebase_auth.dart';
    // import 'package:firebase_database/firebase_database.dart';
    //
    // late DatabaseReference _ref;
    //
    // final idToken = await FirebaseAuth.instance.currentUser!
    //     .getIdTokenResult();
    // final farmaciaId = idToken.claims?['farmacia_id'] as String;
    //
    // _ref = FirebaseDatabase.instance.ref('farmacias/$farmaciaId/alertas');
    // _ref.onValue.listen((event) {
    //   final data = event.snapshot.value as Map? ?? {};
    //   setState(() {
    //     _alertas = data.entries.map((e) {
    //       final v = Map<String, dynamic>.from(e.value as Map);
    //       v['id_alerta'] = e.key;
    //       return v;
    //     }).toList()
    //       ..sort((a, b) =>
    //           (b['score'] as num).compareTo(a['score'] as num));
    //   });
    // });
    // ======================================================
  }

  // Dados fictícios já no formato real retornado por buscar_alertas
  // (chave id_alerta, validade como data, valor_financeiro_risco).
  static final List<Map<String, dynamic>> _dadosFalsos = [
    {
      'id_alerta': 1,
      'medicamento': 'Dipirona 500mg',
      'score': 85.0,
      'tipo': 'vencimento',
      'recomendacao': 'Considere devolução ao distribuidor',
      'valor_financeiro_risco': 2040.00,
      'sobra_projetada': 240,
      'status': 'ABERTO',
      'validade': DateTime.now()
          .add(const Duration(days: 12))
          .toIso8601String()
          .split('T')[0],
      'quantidade': 240,
    },
    {
      'id_alerta': 2,
      'medicamento': 'Amoxicilina 250mg',
      'score': 52.0,
      'tipo': 'discrepancia',
      'recomendacao': 'Monitorar',
      'valor_financeiro_risco': 450.00,
      'sobra_projetada': 30,
      'status': 'ABERTO',
      'validade': DateTime.now()
          .add(const Duration(days: 45))
          .toIso8601String()
          .split('T')[0],
      'quantidade': 30,
    },
    {
      'id_alerta': 3,
      'medicamento': 'Losartana 50mg',
      'score': 20.0,
      'tipo': 'regulatorio',
      'recomendacao': 'Sem ação necessária',
      'valor_financeiro_risco': 0.0,
      'sobra_projetada': 0,
      'status': 'ABERTO',
      'validade': DateTime.now()
          .add(const Duration(days: 120))
          .toIso8601String()
          .split('T')[0],
      'quantidade': 100,
    },
  ];

  Color _corPorScore(double score) {
    if (score >= 70) return Colors.red.shade100;
    if (score >= 40) return Colors.yellow.shade100;
    return Colors.green.shade100;
  }

  // Estrutura preparada para múltiplos tipos de alerta — Ideias 13, 15, 17, 20
  // ignore: unused_element
  Color _corPorTipo(String tipo) {
    switch (tipo) {
      case 'regulatorio':
        return Colors.purple.shade100;
      case 'discrepancia':
        return Colors.orange.shade100;
      case 'esquecido':
        return Colors.grey.shade200;
      case 'campanha_vacinacao':
        return Colors.blue.shade100;
      default:
        return Colors.red.shade100; // vencimento
    }
  }

  // ==========================================================
  // Ideia 04 — Simulador de Prejuízo
  // ==========================================================

  int _calcularDiasRestantes(String validade) {
    final dataValidade = DateTime.parse(validade);
    final hoje = DateTime.now();
    return dataValidade.difference(hoje).inDays;
  }

  String _formatarReais(double valor) {
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    return formatter.format(valor);
  }

  Widget _bannerPrejuizo() {
    final alertasCriticos =
        _alertas.where((a) => (a['score'] as num) >= 40).toList();
    if (alertasCriticos.isEmpty) return const SizedBox.shrink();

    // Pega o alerta de maior score
    alertasCriticos
        .sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
    final pior = alertasCriticos.first;
    final diasRestantes = _calcularDiasRestantes(pior['validade']);
    final valorRisco = (pior['valor_financeiro_risco'] as num?)?.toDouble() ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: 'Alerta de prejuízo: se nenhuma ação for tomada, '
                  '${pior['medicamento']} representa '
                  '${_formatarReais(valorRisco)} em prejuízo projetado '
                  'em $diasRestantes dias',
              child: Text(
                'Se nenhuma ação for tomada, ${pior['medicamento']} '
                'representa ${_formatarReais(valorRisco)} em prejuízo '
                'projetado em $diasRestantes dias.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolverAlerta(dynamic idAlerta, String medicamento) async {
    String? acaoTomada;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolver Alerta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Selecione a ação para $medicamento:'),
            const SizedBox(height: 12),
            for (final acao in ['promocao', 'devolucao', 'monitoramento'])
              ListTile(
                title: Text(acao),
                onTap: () {
                  acaoTomada = acao;
                  Navigator.pop(ctx);
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );

    if (acaoTomada == null) return;

    if (_usarDadosFalsos) {
      // Em modo de teste, só remove da lista local pra simular resolução.
      setState(
          () => _alertas.removeWhere((a) => a['id_alerta'] == idAlerta));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('(teste) Alerta resolvido: $acaoTomada')),
        );
      }
      return;
    }

    try {
      await HttpInterceptor.post('/resolver_alerta', body: {
        'id_alerta': idAlerta,
        'acao_tomada': acaoTomada,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sem conexão. Tente novamente.')),
        );
      }
    }
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
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 16),
              color: Colors.amber.shade100,
              child: const Text(
                'Modo de teste — mostrando dados fictícios (Firebase ainda não conectado)',
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (_alertas.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Nenhum alerta no momento. Seu estoque está controlado.',
                ),
              ),
            )
          else ...[
            _bannerPrejuizo(),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Medicamento')),
                    DataColumn(label: Text('Score')),
                    DataColumn(label: Text('Dias Restantes')),
                    DataColumn(label: Text('Prejuízo Projetado')),
                    DataColumn(label: Text('Recomendação')),
                    DataColumn(label: Text('Ação')),
                  ],
                  rows: _alertas.map((alerta) {
                    final score = (alerta['score'] as num).toDouble();
                    final diasRestantes =
                        _calcularDiasRestantes(alerta['validade']);
                    final valorRisco =
                        (alerta['valor_financeiro_risco'] as num?)
                                ?.toDouble() ??
                            0;

                    return DataRow(
                      color:
                          MaterialStateProperty.all(_corPorScore(score)),
                      cells: [
                        DataCell(Semantics(
                          label: 'Medicamento: ${alerta['medicamento']}',
                          child: Text(alerta['medicamento'] ?? ''),
                        )),
                        DataCell(Semantics(
                          label:
                              'Score de risco: ${score.toStringAsFixed(0)}',
                          child: Text(score.toStringAsFixed(0)),
                        )),
                        DataCell(Text('$diasRestantes dias')),
                        DataCell(
                          score >= 40
                              ? Semantics(
                                  label: 'Prejuízo projetado: '
                                      '${_formatarReais(valorRisco)}',
                                  child: Text(
                                    _formatarReais(valorRisco),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                )
                              : const Text('—'),
                        ),
                        DataCell(Text(alerta['recomendacao'] ?? '')),
                        DataCell(
                          Semantics(
                            button: true,
                            label: 'Resolver alerta de '
                                '${alerta['medicamento']}, '
                                'score ${score.toStringAsFixed(0)}, '
                                '$diasRestantes dias restantes',
                            child: ElevatedButton(
                              onPressed: () => _resolverAlerta(
                                alerta['id_alerta'],
                                alerta['medicamento'],
                              ),
                              child: const Text('Resolver'),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
