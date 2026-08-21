import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../services/http_interceptor.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  // ==========================================================
  // MODO DE TESTE — true enquanto a Function buscar_historico
  // não estiver deployada. Quando a Laysla/Samuel liberarem,
  // trocar para false (ou remover esse bloco todo).
  // ==========================================================
  static const bool _usarDadosFalsos = true;

  int _dias = 30;
  String? _tipoAcao;
  List<Map<String, dynamic>> _historico = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  static final List<Map<String, dynamic>> _dadosFalsos = [
    {
      'farmaceutico': 'Ana Souza',
      'tipo_acao': 'cadastro_lote',
      'descricao': 'Cadastrou lote de Dipirona 500mg',
      'data_hora': '07/07/2026 14:32',
    },
    {
      'farmaceutico': 'Carlos Lima',
      'tipo_acao': 'alerta_resolvido',
      'descricao': 'Resolveu alerta de Amoxicilina 250mg — promoção',
      'data_hora': '06/07/2026 09:15',
    },
    {
      'farmaceutico': 'Ana Souza',
      'tipo_acao': 'pergunta_eva',
      'descricao': 'Perguntou sobre estoque de vacinas',
      'data_hora': '05/07/2026 17:48',
    },
  ];

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    if (_usarDadosFalsos) {
      // Pequeno delay só pra simular carregamento de verdade.
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _historico = _tipoAcao == null
            ? _dadosFalsos
            : _dadosFalsos
                .where((h) => h['tipo_acao'] == _tipoAcao)
                .toList();
        _carregando = false;
      });
      return;
    }

    // ======================================================
    // TODO — QUANDO TIVER A FUNCTION: descomentar e apagar o
    // bloco "if (_usarDadosFalsos)" acima.
    // ======================================================
    try {
      String url = '/buscar_historico?dias=$_dias';
      if (_tipoAcao != null) url += '&tipo_acao=$_tipoAcao';

      final response = await HttpInterceptor.get(url);
      final data = json.decode(response.body);

      setState(() =>
          _historico = List<Map<String, dynamic>>.from(data['historico']));
    } catch (e) {
      setState(() => _historico = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sem conexão. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _traduzirTipo(String tipo) {
    switch (tipo) {
      case 'cadastro_lote':
        return 'Cadastrou Lote';
      case 'alerta_resolvido':
        return 'Resolveu Alerta';
      case 'pergunta_eva':
        return 'Perguntou à EVA';
      default:
        return tipo;
    }
  }

  // ==========================================================
  // Ideia 05 — Relatório de Auditoria ANVISA
  // ==========================================================

  // Flag própria, separada da _usarDadosFalsos do histórico acima,
  // porque depende de uma Function diferente (gerar_relatorio_auditoria)
  // que pode ser deployada em momento diferente de buscar_historico.
  static const bool _usarDadosFalsosRelatorio = true;

  DateTimeRange? _periodoSelecionado;
  bool _gerandoRelatorio = false;

  Future<void> _selecionarPeriodo() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
    );

    if (range != null) {
      setState(() => _periodoSelecionado = range);
    }
  }

  Future<Map<String, dynamic>> _buscarDadosRelatorio() async {
    if (_usarDadosFalsosRelatorio) {
      await Future.delayed(const Duration(milliseconds: 600));
      return {
        'nome_farmacia': 'Farmácia São João',
        'periodo': {
          'inicio':
              _periodoSelecionado!.start.toIso8601String().split('T')[0],
          'fim': _periodoSelecionado!.end.toIso8601String().split('T')[0],
        },
        'alertas': [
          {
            'medicamento': 'Dipirona 500mg',
            'score': 85.0,
            'data_alerta': '2026-07-15T06:00:00',
            'data_resolucao': '2026-07-16T14:30:00',
            'acao_tomada': 'devolucao',
            'status': 'RESOLVIDO',
            'farmaceutico': 'Ana Souza',
            'resolvido_antes_vencimento': true,
          },
          {
            'medicamento': 'Amoxicilina 250mg',
            'score': 58.0,
            'data_alerta': '2026-07-10T06:00:00',
            'data_resolucao': null,
            'acao_tomada': null,
            'status': 'ABERTO',
            'farmaceutico': '—',
            'resolvido_antes_vencimento': false,
          },
        ],
        'resumo': {
          'total_alertas': 2,
          'total_resolvidos_antes_vencimento': 1,
          'percentual_resolucao': 50.0,
          'tempo_medio_resolucao_horas': 32.5,
        },
      };
    }

    // ======================================================
    // TODO — QUANDO TIVER A FUNCTION gerar_relatorio_auditoria:
    // descomentar e apagar o bloco "if (_usarDadosFalsosRelatorio)" acima.
    // ======================================================
    final inicio = _periodoSelecionado!.start.toIso8601String().split('T')[0];
    final fim = _periodoSelecionado!.end.toIso8601String().split('T')[0];

    final response = await HttpInterceptor.get(
      '/gerar_relatorio_auditoria?data_inicio=$inicio&data_fim=$fim',
    );
    return json.decode(response.body);
  }

  Future<Uint8List> _gerarPdf(Map<String, dynamic> dados) async {
    final pdf = pw.Document();
    final alertas = dados['alertas'] as List;
    final resumo = dados['resumo'] as Map<String, dynamic>;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Relatório de Auditoria — ${dados['nome_farmacia']}',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            'Período: ${dados['periodo']['inicio']} a ${dados['periodo']['fim']}',
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Resumo',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Bullet(text: 'Total de alertas gerados: ${resumo['total_alertas']}'),
          pw.Bullet(
            text: 'Resolvidos antes do vencimento: '
                '${resumo['total_resolvidos_antes_vencimento']}',
          ),
          pw.Bullet(
            text: 'Percentual de resolução: ${resumo['percentual_resolucao']}%',
          ),
          pw.Bullet(
            text: 'Tempo médio de resolução: '
                '${resumo['tempo_medio_resolucao_horas'] ?? "—"} horas',
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Alertas do Período',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Table.fromTextArray(
            headers: [
              'Medicamento',
              'Score',
              'Data Alerta',
              'Data Resolução',
              'Ação',
              'Farmacêutico'
            ],
            data: alertas.map((a) {
              return [
                a['medicamento'],
                '${a['score']}',
                (a['data_alerta'] as String).split('T')[0],
                a['data_resolucao'] != null
                    ? (a['data_resolucao'] as String).split('T')[0]
                    : '—',
                a['acao_tomada'] ?? '—',
                a['farmaceutico'],
              ];
            }).toList(),
          ),
        ],
        footer: (context) => pw.Text(
          'Gerado pelo FlemingCore em ${DateTime.now().toString().split('.')[0]}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
    );

    return pdf.save();
  }

  Future<void> _exportarRelatorio() async {
    if (_periodoSelecionado == null) {
      await _selecionarPeriodo();
      if (_periodoSelecionado == null) return;
    }

    setState(() => _gerandoRelatorio = true);

    try {
      final dados = await _buscarDadosRelatorio();
      final pdfBytes = await _gerarPdf(dados);

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'relatorio_auditoria_flemingcore.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Relatório gerado com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao gerar relatório. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _gerandoRelatorio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_usarDadosFalsos || _usarDadosFalsosRelatorio)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 16),
              color: Colors.amber.shade100,
              child: const Text(
                'Modo de teste — mostrando dados fictícios (Functions ainda não deployadas)',
                style: TextStyle(fontSize: 12),
              ),
            ),
          // Filtros + botão de exportação
          Row(
            children: [
              for (final dias in [7, 30, 90])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _dias = dias);
                      _carregar();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _dias == dias ? Colors.blue : Colors.grey,
                    ),
                    child: Text('$dias dias'),
                  ),
                ),
              const SizedBox(width: 16),
              DropdownButton<String?>(
                value: _tipoAcao,
                hint: const Text('Todos'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos')),
                  DropdownMenuItem(
                      value: 'cadastro_lote', child: Text('Cadastrou Lote')),
                  DropdownMenuItem(
                      value: 'alerta_resolvido',
                      child: Text('Resolveu Alerta')),
                  DropdownMenuItem(
                      value: 'pergunta_eva', child: Text('Perguntou à EVA')),
                ],
                onChanged: (v) {
                  setState(() => _tipoAcao = v);
                  _carregar();
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _gerandoRelatorio ? null : _exportarRelatorio,
                icon: _gerandoRelatorio
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: const Text('Exportar Relatório ANVISA'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_carregando)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_historico.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Nenhuma atividade encontrada para os filtros selecionados.',
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Farmacêutico')),
                    DataColumn(label: Text('Tipo de Ação')),
                    DataColumn(label: Text('Descrição')),
                    DataColumn(label: Text('Data e Hora')),
                  ],
                  rows: _historico.map((h) {
                    return DataRow(cells: [
                      DataCell(Text(h['farmaceutico'] ?? '—')),
                      DataCell(Text(_traduzirTipo(h['tipo_acao']))),
                      DataCell(Text(h['descricao'])),
                      DataCell(Text(h['data_hora'])),
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
