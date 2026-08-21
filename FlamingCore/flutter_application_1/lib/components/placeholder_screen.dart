import 'package:flutter/material.dart';

/// Tela genérica usada como placeholder enquanto a tela real
/// não é implementada. Assim o app compila e a navegação
/// pode ser testada de ponta a ponta antes de cada tela existir.
class PlaceholderScreen extends StatelessWidget {
  final String titulo;
  final IconData icone;

  const PlaceholderScreen({
    super.key,
    required this.titulo,
    this.icone = Icons.construction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tela ainda não implementada.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
