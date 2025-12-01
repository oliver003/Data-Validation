import 'package:flutter/material.dart';
import 'package:flutter_application_2/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter_application_2/vistas/cliente.dart';
import 'package:flutter_application_2/vistas/inicio.dart';
import 'package:flutter_application_2/vistas/contable.dart';
import 'package:flutter_application_2/vistas/cajera.dart';
import 'package:flutter_application_2/vistas/login.dart';

class AppData {
  static String nombre = '';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase solo en plataformas soportadas
  if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const MainApp());
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
        '/Contable': (context) => const Contable(),
        '/Cajera': (context) => const Cajera(),
      }
    );
  }
}
