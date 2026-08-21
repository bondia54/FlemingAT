import 'package:flutter/material.dart';
import 'farmaceutico/main_layout_farmaceutico.dart';
import 'eurofarma/main_layout_eurofarma.dart';
import 'login/login_screen.dart';

/// Tela temporária, SÓ PRA TESTES, enquanto o login real
/// (que depende do Firebase) não está disponível.
///
/// Remover e trocar por LoginScreen assim que o Josué liberar
/// o acesso ao projeto Firebase.
class TempHomeScreen extends StatelessWidget {
  const TempHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Modo de teste — sem login (Firebase pendente)',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MainLayoutFarmaceutico()),
              ),
              child: const Text('Testar layout Farmacêutico'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MainLayoutEurofarma()),
              ),
              child: const Text('Testar layout Eurofarma'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Testar tela de Login (sem Firebase ativo)'),
            ),
          ],
        ),
      ),
    );
  }
}
