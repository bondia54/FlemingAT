import 'package:flutter/material.dart';

class SidebarEurofarma extends StatelessWidget {
  final String paginaAtiva;
  final Function(String) onNavegar;
  final String nomeUsuario;

  const SidebarEurofarma({
    super.key,
    required this.paginaAtiva,
    required this.onNavegar,
    required this.nomeUsuario,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF1C2620),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Image.asset(
              'assets/logo.png',
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    'FlemingCore',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
          // 5 itens — Eurofarma não tem Devoluções, então sem badge.
          _item('dashboard', 'Dashboard', Icons.dashboard),
          _item('termometro', 'Termômetro de Giro', Icons.bar_chart),
          _item('vulnerabilidade', 'Vulnerabilidade Farmacêutica',
              Icons.warning),
          _item('impacto_social', 'Impacto Social', Icons.people),
          _item('conformidade', 'Conformidade', Icons.verified),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(nomeUsuario,
                    style: const TextStyle(color: Colors.white70)),
                TextButton(
                  onPressed: () {
                    // TODO: FirebaseAuth.instance.signOut()
                    // Comentado até integração com Firebase estar disponível.
                  },
                  child: const Text('Sair',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(String id, String label, IconData icon) {
    final ativo = paginaAtiva == id;
    return ListTile(
      leading: Icon(icon, color: ativo ? Colors.white : Colors.white54),
      title: Text(label,
          style: TextStyle(color: ativo ? Colors.white : Colors.white54)),
      tileColor: ativo ? Colors.white12 : Colors.transparent,
      onTap: () => onNavegar(id),
    );
  }
}
