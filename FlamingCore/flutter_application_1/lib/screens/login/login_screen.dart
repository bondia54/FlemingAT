import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../farmaceutico/main_layout_farmaceutico.dart';
import '../eurofarma/main_layout_eurofarma.dart';
import '../../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 'farmaceutico' ou 'eurofarma'
  String? _tipoSelecionado;

  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _senhaVisivel = false;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  /// Decodifica manualmente o payload de um JWT (parte do meio, entre os
  /// dois pontos), sem depender de pacotes externos.
  ///
  /// Necessário porque `User.getIdTokenResult().claims` retorna sempre
  /// null no Windows Desktop — é um bug conhecido do plugin firebase_auth
  /// nessa plataforma (issues #11768 e #11949 no repositório FlutterFire).
  /// `getIdToken()` (o token bruto) funciona normalmente em todas as
  /// plataformas, então decodificamos o JWT na mão.
  Map<String, dynamic> _decodificarClaimsDoToken(String token) {
    final partes = token.split('.');
    if (partes.length != 3) return {};

    String payload = partes[1];
    // Base64Url exige que o comprimento seja múltiplo de 4.
    payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');

    final decodedBytes = base64Url.decode(payload);
    final decodedString = utf8.decode(decodedBytes);
    return json.decode(decodedString) as Map<String, dynamic>;
  }

  Future<void> _entrar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final credencial = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );

      // getIdToken(true) força buscar um token novo do servidor, já
      // com os custom claims mais recentes.
      final tokenBruto = await credencial.user!.getIdToken(true);
      final claims = _decodificarClaimsDoToken(tokenBruto!);
      final tipoUsuario = claims['tipo_usuario'] as String?;

      if (tipoUsuario == null) {
        await FirebaseAuth.instance.signOut();
        setState(() => _erro = 'Usuário sem permissão configurada.');
        return;
      }

      // Verificar se o tipo bate com o botão selecionado
      final tipoEsperado =
          _tipoSelecionado == 'farmaceutico' ? 'FARMACEUTICO' : 'EUROFARMA';

      if (tipoUsuario != tipoEsperado) {
        await FirebaseAuth.instance.signOut();
        setState(
            () => _erro = 'Acesso não autorizado para este tipo de usuário.');
        return;
      }

      if (!mounted) return;

      if (tipoUsuario == 'FARMACEUTICO') {
        // Notificação nativa só é habilitada pro farmacêutico —
        // nunca pra Eurofarma nem Distribuidor.
        await NotificationService.iniciar();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainLayoutFarmaceutico()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainLayoutEurofarma()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _erro = e.code == 'network-request-failed'
            ? 'Sem conexão com a internet.'
            : 'Email ou senha incorretos.';
      });
    } catch (e) {
      // Cobre o caso de Firebase ainda não estar inicializado
      // (enquanto o firebase_options.dart não existir).
      setState(() {
        _erro = 'Firebase ainda não configurado neste ambiente.';
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camposVazios = _emailController.text.isEmpty ||
        _senhaController.text.isEmpty ||
        _tipoSelecionado == null;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 80,
                  errorBuilder: (context, error, stackTrace) => const Text(
                    'FlemingCore',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
                // Botões de tipo de usuário
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: _tipoSelecionado == 'farmaceutico',
                        label: 'Entrar como Farmacêutico',
                        child: ElevatedButton(
                          onPressed: () => setState(
                              () => _tipoSelecionado = 'farmaceutico'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _tipoSelecionado == 'farmaceutico'
                                    ? Colors.blue
                                    : Colors.grey,
                          ),
                          child: const Text('Entrar como Farmacêutico'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: _tipoSelecionado == 'eurofarma',
                        label: 'Entrar como Eurofarma',
                        child: ElevatedButton(
                          onPressed: () =>
                              setState(() => _tipoSelecionado = 'eurofarma'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _tipoSelecionado == 'eurofarma'
                                ? Colors.orange
                                : Colors.grey,
                          ),
                          child: const Text('Entrar como Eurofarma'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Semantics(
                  textField: true,
                  label: 'Campo de email',
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  textField: true,
                  label: 'Campo de senha',
                  obscured: !_senhaVisivel,
                  child: TextField(
                    controller: _senhaController,
                    obscureText: !_senhaVisivel,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      suffixIcon: Semantics(
                        button: true,
                        label: _senhaVisivel
                            ? 'Ocultar senha'
                            : 'Mostrar senha',
                        child: IconButton(
                          icon: Icon(_senhaVisivel
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _senhaVisivel = !_senhaVisivel),
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (!camposVazios && !_carregando) _entrar();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (_erro != null)
                  Semantics(
                    liveRegion: true,
                    child:
                        Text(_erro!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  enabled: !(camposVazios || _carregando),
                  label: camposVazios
                      ? 'Botão Entrar desabilitado — preencha email e senha'
                      : (_carregando ? 'Entrando' : 'Entrar no sistema'),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: camposVazios || _carregando ? null : _entrar,
                      child: _carregando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Entrar'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
