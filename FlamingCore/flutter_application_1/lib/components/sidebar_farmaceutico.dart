import 'package:flutter/material.dart';

class SidebarFarmaceutico extends StatelessWidget {
  final String paginaAtiva;
  final Function(String) onNavegar;
  final String nomeFarmaceutico;

  // Contagem de devoluções pendentes — Ideia 06 do documento.
  // Por enquanto fixo em 0; Semana 3+ isso vem do backend.
  final int contagemDevolucoes;

  const SidebarFarmaceutico({
    super.key,
    required this.paginaAtiva,
    required this.onNavegar,
    required this.nomeFarmaceutico,
    this.contagemDevolucoes = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF1C2620),
      child: Column(
        children: [
          // Logo no topo
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
          // Itens de navegação
          _item('alertas', 'Alertas', Icons.notifications),
          _item('cadastrar_lote', 'Cadastrar Lote', Icons.add_box),
          _item('historico', 'Histórico', Icons.history),
          _itemComBadge('devolucoes', 'Devoluções', Icons.assignment_return,
              contagemDevolucoes),
          _item('eva', 'EVA', Icons.chat),
          const Spacer(),
          // Nome e logout na parte inferior
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(nomeFarmaceutico,
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

  Widget _itemComBadge(String id, String label, IconData icon, int count) {
    return Stack(
      children: [
        _item(id, label, icon),
        if (count > 0)
          Positioned(
            right: 16,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
