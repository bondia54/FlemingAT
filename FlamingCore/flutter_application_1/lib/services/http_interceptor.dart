import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Centraliza todas as chamadas HTTP para as Cloud Functions.
/// Regra que nunca pode ser quebrada: toda chamada leva o token
/// Firebase no cabeçalho Authorization.
class HttpInterceptor {
  // TODO: trocar pela URL real assim que a Laysla/Samuel deployarem
  // as Functions (ver documento de junho — "URLs de todas as Functions").
  static const String _baseUrl = 'https://[URL_DAS_FUNCTIONS]';

  static Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado');
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw Exception('Não foi possível obter o token de autenticação');
    }
    return token;
  }

  static Future<http.Response> get(String path) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      await FirebaseAuth.instance.signOut();
      throw Exception('Sessão expirada');
    }

    return response;
  }

  static Future<http.Response> post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 401) {
      await FirebaseAuth.instance.signOut();
      throw Exception('Sessão expirada');
    }

    return response;
  }
}
