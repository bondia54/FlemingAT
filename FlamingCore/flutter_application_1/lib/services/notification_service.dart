import 'package:local_notifier/local_notifier.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Notificações nativas do Windows, disparadas quando uma mensagem
/// do Firebase Cloud Messaging chega.
///
/// Regra do documento de junho/julho: notificação SÓ para farmacêutico
/// — nunca para Eurofarma nem Distribuidor.
class NotificationService {
  static bool _inicializado = false;

  /// Chamar uma vez, logo depois do login bem-sucedido como farmacêutico.
  static Future<void> iniciar() async {
    if (_inicializado) return;

    // Confirma que o usuário logado é farmacêutico antes de habilitar
    // qualquer notificação. Eurofarma e Distribuidor nunca recebem.
    final idToken =
        await FirebaseAuth.instance.currentUser?.getIdTokenResult();
    final tipoUsuario = idToken?.claims?['tipo_usuario'] as String?;
    if (tipoUsuario != 'FARMACEUTICO') return;

    await localNotifier.setup(
      appName: 'FlemingCore',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );

    // Pede permissão de notificação (necessário em algumas plataformas).
    await FirebaseMessaging.instance.requestPermission();

    // Mensagens recebidas com o app aberto (foreground).
    FirebaseMessaging.onMessage.listen(_exibirNotificacao);

    // Mensagens recebidas com o app em segundo plano ou fechado
    // já são tratadas pelo próprio sistema operacional via FCM,
    // mas ainda registramos o handler pra quando o app reabre por
    // causa de um clique na notificação.
    FirebaseMessaging.onMessageOpenedApp.listen(_exibirNotificacao);

    _inicializado = true;
  }

  static Future<void> _exibirNotificacao(RemoteMessage message) async {
    final notification = LocalNotification(
      title: message.notification?.title ?? 'FlemingCore',
      body: message.notification?.body ?? '',
    );
    notification.show();
  }
}
