import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';  // Generado por flutterfire configure
import 'vistas/contable.dart';
import 'vistas/inicio.dart';
import 'vistas/cliente.dart';
import 'vistas/cajera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp()
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contabilidad Ilumel',
      debugShowCheckedModeBanner: false,
      initialRoute: '/Inicio',
      routes: {
        '/Inicio': (context) => const Inicio(),  // Tu pantalla de inicio/login
        '/Cliente': (context) => const Cliente(),
        '/Contable': (context) => Contable(),  // Integra aquí el flujo de contabilidad
        '/Cajera': (context) => const Cajera(),
       
  });
  }
}

// Ejemplos de clases de pantalla (reemplaza con tus implementaciones reales)
// Si ya tienes estas clases, ignora y ajusta imports.

