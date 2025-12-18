import 'package:flutter/material.dart';

import 'vistas_windows/cliente.dart';
import 'vistas_windows/inicio.dart';
import 'vistas_windows/contable.dart';
import 'vistas_windows/cajera.dart';
import 'vistas_windows/login.dart';

class AppData {
  static String nombre = '';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MainAppWindows());
}

class MainAppWindows extends StatelessWidget {
  const MainAppWindows({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contabilidad Ilumel',
      debugShowCheckedModeBanner: false,
      initialRoute: '/Login',
      routes: {
        '/Login': (context) => const LoginView(),
        '/Inicio': (context) => const Inicio(),
        '/Cliente': (context) => const ClienteWindows(),
        '/Contable': (context) => const ContableWindows(),
        '/Cajera': (context) => const CajeraWindows(),
      }
    );
  }
}
