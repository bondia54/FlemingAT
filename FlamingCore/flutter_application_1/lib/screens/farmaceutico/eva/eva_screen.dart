import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/http_interceptor.dart';

class EvaScreen extends StatefulWidget {
  const EvaScreen({super.key});

  @override
  State<EvaScreen> createState() => _EvaScreenState();
}

class _EvaScreenState extends State<EvaScreen> {
  // ==========================================================
  // MODO DE TESTE — true enquanto a Function eva_chat e o
  // Realtime Database não estiverem disponíveis. Quando a
  // Laysla/Samuel e o Josué liberarem, trocar para false
  // (ou remover esse bloco todo).
  // ==========================================================
  static const bool _usarDadosFalsos = true;

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _mensagens = [];
  bool _aguardando = false;

  // Painel de contexto — alertas críticos (score >= 70)
  List<Map<String, dynamic>> _alertasCriticos = [];

  @override
  void initState() {
    super.initState();

    if (_usarDadosFalsos) {
      _alertasCriticos = _alertasCriticosFalsos;
    }

    // ======================================================
    // TODO — QUANDO TIVER FIREBASE: descomentar e apagar o
    // bloco "if (_usarDadosFalsos)" acima. Mesmo listener
    // usado em alertas_screen.dart, só que filtrado por score.
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
    //     _alertasCriticos = data.entries
    //         .map((e) {
    //           final v = Map<String, dynamic>.from(e.value as Map);
    //           v['id'] = e.key;
    //           return v;
    //         })
    //         .where((a) => (a['score'] as num) >= 70)
    //         .toList()
    //       ..sort((a, b) =>
    //           (b['score'] as num).compareTo(a['score'] as num));
    //   });
    // });
    // ======================================================
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static final List<Map<String, dynamic>> _alertasCriticosFalsos = [
    {
      'medicamento': 'Dipirona 500mg',
      'score': 85,
      'dias_restantes': 12,
    },
  ];

  Future<void> _enviar() async {
    final pergunta = _controller.text.trim();
    if (pergunta.isEmpty) return;

    setState(() {
      _mensagens.add({'tipo': 'usuario', 'texto': pergunta});
      _aguardando = true;
    });
    _controller.clear();
    _rolarParaBaixo();

    if (_usarDadosFalsos) {
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        _mensagens.add({
          'tipo': 'eva',
          'texto': '(teste) Ainda não estou conectada aos dados reais da '
              'farmácia, mas em breve vou poder responder sobre estoque, '
              'validade e alertas de verdade.',
        });
        _aguardando = false;
      });
      _rolarParaBaixo();
      return;
    }

    // ======================================================
    // TODO — QUANDO TIVER A FUNCTION: descomentar e apagar o
    // bloco "if (_usarDadosFalsos)" acima.
    // ======================================================
    try {
      final response = await HttpInterceptor.post(
        '/eva_chat',
        body: {'pergunta': pergunta},
      );
      final data = json.decode(response.body);
      setState(() {
        _mensagens.add({'tipo': 'eva', 'texto': data['resposta']});
      });
    } catch (e) {
      setState(() {
        _mensagens.add({
          'tipo': 'eva',
          'texto': 'Sem conexão. Verifique a internet e tente novamente.',
        });
      });
    } finally {
      if (mounted) setState(() => _aguardando = false);
      _rolarParaBaixo();
    }
  }

  void _rolarParaBaixo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Coluna do chat — 60%
        Expanded(
          flex: 6,
          child: Column(
            children: [
              if (_usarDadosFalsos)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.amber.shade100,
                  child: const Text(
                    'Modo de teste — EVA ainda não conectada à Function real',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              Expanded(
                child: _mensagens.isEmpty
                    ? const Center(
                        child: Text(
                          'Pergunte algo sobre o estoque para começar.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _mensagens.length + (_aguardando ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (_aguardando && i == _mensagens.length) {
                            return const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('...'),
                              ),
                            );
                          }
                          final m = _mensagens[i];
                          final isUsuario = m['tipo'] == 'usuario';
                          return Align(
                            alignment: isUsuario
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Semantics(
                              label: isUsuario
                                  ? 'Você disse: ${m['texto']}'
                                  : 'EVA respondeu: ${m['texto']}',
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(12),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.35,
                                ),
                                decoration: BoxDecoration(
                                  color: isUsuario
                                      ? Colors.blue
                                      : Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  m['texto']!,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Input
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                                      child: Semantics(
                        textField: true,
                        label: 'Digite sua pergunta para a EVA',
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Pergunte algo sobre o estoque…',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _enviar(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      enabled: !_aguardando,
                      label: 'Enviar pergunta para a EVA',
                      child: ElevatedButton(
                        onPressed: _aguardando ? null : _enviar,
                        child: const Text('Enviar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Painel de contexto — 40%
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alertas Críticos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (_alertasCriticos.isEmpty)
                  const Text(
                    'Nenhum alerta crítico no momento.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  ..._alertasCriticos.map((a) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning, color: Colors.red),
                          title: Text(a['medicamento'] ?? ''),
                          subtitle:
                              Text('${a['dias_restantes']} dias restantes'),
                          trailing: Text('${a['score']}'),
                        ),
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
