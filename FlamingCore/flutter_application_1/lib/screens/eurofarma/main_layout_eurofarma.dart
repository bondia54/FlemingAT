import 'package:flutter/material.dart';
import '../../components/sidebar_eurofarma.dart';
import 'dashboard/dashboard_eurofarma_screen.dart';
import 'termometro/termometro_screen.dart';
import 'vulnerabilidade/vulnerabilidade_screen.dart';
import 'impacto_social/impacto_social_screen.dart';
import 'conformidade/conformidade_screen.dart';

class MainLayoutEurofarma extends StatefulWidget {
  const MainLayoutEurofarma({super.key});

  @override
  State<MainLayoutEurofarma> createState() => _MainLayoutEurofarmaState();
}

class _MainLayoutEurofarmaState extends State<MainLayoutEurofarma> {
  String _paginaAtiva = 'dashboard';

  Widget _paginaAtual() {
    switch (_paginaAtiva) {
      case 'dashboard':
        return DashboardEurofarmaScreen(
          onNavegar: (id) => setState(() => _paginaAtiva = id),
        );
      case 'termometro':
        return const TermometroScreen();
      case 'vulnerabilidade':
        return const VulnerabilidadeScreen();
      case 'impacto_social':
        return const ImpactoSocialScreen();
      case 'conformidade':
        return const ConformidadeScreen();
      default:
        return const DashboardEurofarmaScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SidebarEurofarma(
            paginaAtiva: _paginaAtiva,
            onNavegar: (id) => setState(() => _paginaAtiva = id),
            // TODO: pegar nome real do usuário via custom claims (Firebase).
            nomeUsuario: 'Eurofarma',
          ),
          Expanded(child: _paginaAtual()),
        ],
      ),
    );
  }
}
