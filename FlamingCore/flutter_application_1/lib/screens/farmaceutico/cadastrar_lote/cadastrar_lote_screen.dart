import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/http_interceptor.dart';

class CadastrarLoteScreen extends StatefulWidget {
  const CadastrarLoteScreen({super.key});

  @override
  State<CadastrarLoteScreen> createState() => _CadastrarLoteScreenState();
}

class _CadastrarLoteScreenState extends State<CadastrarLoteScreen> {
  final _codigoBarrasController = TextEditingController();
  final _numeroLoteController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _precoController = TextEditingController();
  final _codigoBarrasFocus = FocusNode();

  String? _nomeMedicamento;
  int? _idMedicamento;
  DateTime? _dataValidade;

  bool _buscando = false;
  bool _salvando = false;
  String? _mensagem;

  @override
  void initState() {
    super.initState();
    // Foco automático no campo de código de barras ao abrir a tela,
    // assim o leitor USB pode escanear direto sem precisar clicar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _codigoBarrasFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _codigoBarrasController.dispose();
    _numeroLoteController.dispose();
    _quantidadeController.dispose();
    _precoController.dispose();
    _codigoBarrasFocus.dispose();
    super.dispose();
  }

  Future<void> _buscarMedicamento(String codigo) async {
    if (codigo.trim().isEmpty) return;

    setState(() {
      _buscando = true;
      _nomeMedicamento = null;
      _mensagem = null;
    });

    try {
      final response =
          await HttpInterceptor.get('/buscar_medicamento?codigo_barras=$codigo');
      final data = json.decode(response.body);

      if (data['encontrado'] == true) {
        setState(() {
          _idMedicamento = data['id_medicamento'];
          _nomeMedicamento = data['nome'];
        });
      } else {
        setState(() {
          _nomeMedicamento = null;
          _idMedicamento = null;
          _mensagem = 'Medicamento não cadastrado — será criado ao salvar.';
        });
      }
    } catch (e) {
      setState(() => _mensagem = 'Sem conexão. Verifique a internet.');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _mensagem = null;
    });

    try {
      await HttpInterceptor.post('/cadastrar_lote', body: {
        'numero_lote': _numeroLoteController.text,
        'validade': _dataValidade!.toIso8601String().split('T')[0],
        'quantidade': int.parse(_quantidadeController.text),
        'preco_unitario': double.tryParse(_precoController.text),
        'id_medicamento': _idMedicamento,
      });

      // Limpar campos e devolver foco ao código de barras
      _codigoBarrasController.clear();
      _numeroLoteController.clear();
      _quantidadeController.clear();
      _precoController.clear();

      setState(() {
        _nomeMedicamento = null;
        _idMedicamento = null;
        _dataValidade = null;
        _mensagem = 'Lote cadastrado com sucesso.';
      });

      _codigoBarrasFocus.requestFocus();
    } catch (e) {
      setState(() => _mensagem = 'Erro ao salvar. Dados mantidos.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camposVazios = _numeroLoteController.text.isEmpty ||
        _quantidadeController.text.isEmpty ||
        _dataValidade == null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cadastrar Lote',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // Campo de código de barras — o leitor USB digita e manda Enter
          Row(
            children: [
              Expanded(
                child: Semantics(
                  textField: true,
                  label:
                      'Campo de código de barras — aponte o leitor USB para escanear',
                  child: TextField(
                    controller: _codigoBarrasController,
                    focusNode: _codigoBarrasFocus,
                    decoration: const InputDecoration(
                      labelText: 'Código de Barras',
                      hintText: 'Aponte o leitor USB para a caixa',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _buscarMedicamento,
                  ),
                ),
              ),
              if (_buscando)
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          // Nome do medicamento encontrado — só leitura
          if (_nomeMedicamento != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey.shade100,
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(_nomeMedicamento!),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _numeroLoteController,
            decoration: const InputDecoration(
              labelText: 'Número do Lote',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantidadeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantidade',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _precoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Preço Unitário (R\$)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // DatePicker — mínimo hoje, máximo 5 anos
          ElevatedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            onPressed: () async {
              final data = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 1825)),
              );
              if (data != null) setState(() => _dataValidade = data);
            },
            label: Text(
              _dataValidade == null
                  ? 'Selecionar Data de Validade'
                  : 'Validade: ${_dataValidade!.day.toString().padLeft(2, '0')}/'
                      '${_dataValidade!.month.toString().padLeft(2, '0')}/'
                      '${_dataValidade!.year}',
            ),
          ),
          if (_mensagem != null) ...[
            const SizedBox(height: 12),
            Text(
              _mensagem!,
              style: TextStyle(
                color: _mensagem!.contains('sucesso')
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Semantics(
            button: true,
            enabled: !(camposVazios || _salvando),
            label: camposVazios
                ? 'Salvar desabilitado — preencha todos os campos obrigatórios'
                : 'Salvar lote de ${_nomeMedicamento ?? "medicamento"}',
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: camposVazios || _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Salvar Lote'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
