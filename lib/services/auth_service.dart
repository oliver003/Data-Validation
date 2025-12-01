import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final String projectId = "tickets-firebase-aba0a"; // ID de Firebase

  Future<Map<String, dynamic>?> login(String codigo, String password) async {
    // Si estamos en Android/iOS/Web, usar el plugin oficial
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      final doc = await FirebaseFirestore.instance
          .collection('Usuarios')
          .doc(codigo)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return data['Password'] == password ? data : null;
    }

    // Si estamos en Windows, usar REST API
    else if (Platform.isWindows) {
      final url = Uri.parse(
        "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/Usuarios/$codigo",
      );

      final response = await http.get(url);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);

      // Los campos vienen en formato Firestore REST: { fields: { Password: { stringValue: "..." } } }
      final fields = data['fields'] as Map<String, dynamic>;
      final storedPassword = fields['Password']['stringValue'];

      if (storedPassword == password) {
        // Convertir todos los campos a un Map<String, dynamic> plano
        final result = fields.map((key, value) {
          final typeKey = value.keys.first;
          return MapEntry(key, value[typeKey]);
        });
        return result;
      } else {
        return null;
      }
    }

    // Otras plataformas
    return null;
  }
}
