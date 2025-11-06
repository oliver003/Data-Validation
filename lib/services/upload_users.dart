// ignore: file_names
// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_application_2/firebase_options.dart';

/// Llama a esta función desde `main.dart` si quieres ejecutar la carga de CSV.
/// Lee el asset 'assets/usuarios.csv' (debe estar registrado en pubspec.yaml).
Future<void> uploadUsers() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final firestore = FirebaseFirestore.instance;

  String? csvContent;
  try {
    csvContent = await rootBundle.loadString('assets/usuarios.csv');
    print('[uploadUsers] Leyendo usuarios.csv desde assets/usuarios.csv');
  } catch (e) {
    print('[uploadUsers] Asset assets/usuarios.csv no encontrado: $e');
    return;
  }

  if (csvContent.trim().isEmpty) {
    print('[uploadUsers] El archivo CSV está vacío.');
    return;
  }

  final lines = csvContent.split(RegExp(r'\r?\n'));
  if (lines.length <= 1) {
    print('[uploadUsers] CSV vacío o solo cabecera. Nada para procesar.');
    return;
  }

  int inserted = 0;
  int skipped = 0;

  // Omitimos la cabecera (1ra línea)
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) {
      skipped++;
      continue;
    }

    final parts = line.split(',');
    if (parts.length < 4) {
      skipped++;
      print('[uploadUsers] Línea $i ignorada (campos insuficientes): "$line"');
      continue;
    }

    final codigo = parts[0].trim();
    final usuario = parts[1].trim();
    final password = parts[2].trim();
    final rol = parts[3].trim();

    try {
      await firestore.collection('Usuarios').doc(codigo).set({
        'Codigo': codigo,
        'Nombre': usuario,
        'Password': password,
        'Rol': rol,
      });
      inserted++;
      print('[uploadUsers] Insertado $codigo');
    } catch (e) {
      skipped++;
      print('[uploadUsers] Error insertando $codigo: $e');
    }
  }

  print('[uploadUsers] Proceso finalizado. Insertados: $inserted, Ignorados: $skipped');
}
