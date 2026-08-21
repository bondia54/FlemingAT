import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/http_interceptor.dart';

class DevolucoesScreen extends StatefulWidget {
  const DevolucoesScreen({super.key});

  @override
  State<DevolucoesScreen> createState() => _DevolucoesScreenState();
}

class _DevolucoesScreenState extends State<DevolucoesScreen> {
  // ==========================================================
  // MODO DE TESTE — true enquanto a Function
  // buscar_solicitacoes_devolucao não estiver deployada.
  // Quando o Samuel confirmar o deploy, trocar para false.
  // ==========================================================
  static const bool _usarDadosFalsos = true;

  List<Map<String, dynamic>> _solicitacoes = [];
  bool _carregando = false;
  String? _filtroStatus; // null = todos, 'PENDENTE' ou 'ENVIADA'

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  static final List<Map<String, dynamic>> _dadosFalsos = [
    {
      'id': 1,
      'medicamento': 'Dipirona 500mg',
      'lote': 'L2024-001',
      'quantidade': 45,
      'validade': '20/07/2026',
      'data_solicitacao': '10/07/2026',
      'status': 'PENDENTE',
    },
    {
      'id': 2,
      'medicamento': 'Amoxicilina 250mg',
      'lote': 'L2024-018',
      'quantidade': 30,
      'validade': '05/08/2026',
      'data_solicitacao': '08/07/2026',
      'status': 'ENVIADA',
    },
  ];

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    if (_usarDadosFalsos) {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _solicitacoes = _filtroStatus == null
            ? _dadosFalsos
            : _dadosFalsos.where((s) => s['status'] == _filtroStatus).toList();
        _carregando = false;
      });
      return;
    }

    // ======================================================
    // TODO — QUANDO TIVER A FUNCTION buscar_solicitacoes_devolucao:
    // descomentar e apagar o bloco "if (_usarDadosFalsos)" acima.
    // ======================================================
    try {
      String url = '/buscar_solicitacoes_devolucao';
      if (_filtroStatus != null) url += '?status=$_filtroStatus';

      final response = await HttpInterceptor.get(url);
      final data = json.decode(response.body);

      setState(() => _solicitacoes =
          List<Map<String, dynamic>>.from(data['solicitacoes']));
    } catch (e) {
      setState(() => _solicitacoes = []);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _marcarEnviada(int id) async {
    if (_usarDadosFalsos) {
      setState(() {
        final item = _dadosFalsos.firstWhere((s) => s['id'] == id);
        item['status'] = 'ENVIADA';
      });
      return;
    }

    // TODO — QUANDO TIVER A FUNCTION: chamar marcar_solicitacao_enviada
    // try {
    //   await HttpInterceptor.post('/marcar_solicitacao_enviada', body: {
    //     'id_solicitacao': id,
    //   });
    //   _carregar();
    // } catch (e) {
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text('Sem conexão. Tente novamente.')),
    //     );
    //   }
    // }
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
                'Modo de teste — dados fictícios (Function ainda não deployada)',
                style: TextStyle(fontSize: 12),
              ),
            ),
          Row(
            children: [
              const Text('Devoluções',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              DropdownButton<String?>(
                value: _filtroStatus,
                hint: const Text('Todos'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos')),
                  DropdownMenuItem(value: 'PENDENTE', child: Text('Pendente')),
                  DropdownMenuItem(value: 'ENVIADA', child: Text('Enviada')),
                ],
                onChanged: (v) {
                  setState(() => _filtroStatus = v);
                  _carregar();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_carregando)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_solicitacoes.isEmpty)
            const Expanded(
                child: Center(child: Text('Nenhuma solicitação encontrada.')))
          else
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Medicamento')),
                    DataColumn(label: Text('Lote')),
                    DataColumn(label: Text('Quantidade')),
                    DataColumn(label: Text('Validade')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Ação')),
                  ],
                  rows: _solicitacoes.map((s) {
                    return DataRow(cells: [
                      DataCell(Text(s['medicamento'])),
                      DataCell(Text(s['lote'])),
                      DataCell(Text('${s['quantidade']}')),
                      DataCell(Text(s['validade'])),
                      DataCell(Text(s['status'])),
                      DataCell(
                        s['status'] == 'PENDENTE'
                            ? ElevatedButton(
                                onPressed: () => _marcarEnviada(s['id']),
                                child: const Text('Marcar Enviada'),
                              )
                            : const Text('—'),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
