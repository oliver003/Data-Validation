import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:flutter_application_2/vistas/cliente.dart';
import 'package:flutter_application_2/vistas/inicio.dart';
import 'package:flutter_application_2/vistas/contable.dart';
import 'package:flutter_application_2/vistas/cajera.dart';
import 'package:flutter_application_2/vistas/login.dart';

class AppData {
  static String nombre = '';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform);
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
      initialRoute: '/Login',
      routes: {
        '/Login': (context) => const LoginView(),
        '/Inicio': (context) => const Inicio(),
        '/Cliente': (context) => const Cliente(),
        '/Contable': (context) => Contable(),  // Integra aquí el flujo de contabilidad
        '/Cajera': (context) => const Cajera(),
      }
    );
  }
}

// Ejemplos de clases de pantalla (reemplaza con tus implementaciones reales)
// Si ya tienes estas clases, ignora y ajusta imports.

