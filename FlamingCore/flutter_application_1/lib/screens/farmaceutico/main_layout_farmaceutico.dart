import 'package:flutter/material.dart';
import '../../components/sidebar_farmaceutico.dart';
import 'alertas/alertas_screen.dart';
import 'cadastrar_lote/cadastrar_lote_screen.dart';
import 'historico/historico_screen.dart';
import 'devolucoes/devolucoes_screen.dart';
import 'eva/eva_screen.dart';

class MainLayoutFarmaceutico extends StatefulWidget {
  const MainLayoutFarmaceutico({super.key});

  @override
  State<MainLayoutFarmaceutico> createState() =>
      _MainLayoutFarmaceuticoState();
}

class _MainLayoutFarmaceuticoState extends State<MainLayoutFarmaceutico> {
  String _paginaAtiva = 'alertas';

  Widget _paginaAtual() {
    switch (_paginaAtiva) {
      case 'alertas':
        return const AlertasScreen();
      case 'cadastrar_lote':
        return const CadastrarLoteScreen();
      case 'historico':
        return const HistoricoScreen();
      case 'devolucoes':
        return const DevolucoesScreen();
      case 'eva':
        return const EvaScreen();
      default:
        return const AlertasScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SidebarFarmaceutico(
            paginaAtiva: _paginaAtiva,
            onNavegar: (id) => setState(() => _paginaAtiva = id),
            // TODO: pegar nome real do usuário via custom claims (Firebase).
            nomeFarmaceutico: 'Farmacêutico',
          ),
          Expanded(child: _paginaAtual()),
        ],
      ),
    );
  }
}
