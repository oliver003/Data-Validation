import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/auth_service.dart';

/*import 'package:flutter_application_2/vistas/inicio.dart';
import 'package:flutter_application_2/vistas/cliente.dart';
import 'package:flutter_application_2/vistas/contable.dart';
import 'package:flutter_application_2/vistas/cajera.dart';*/

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final AuthService _authService = AuthService();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);

    final codigo = _codigoController.text.trim();
    final password = _passwordController.text.trim();

    final usuario = await _authService.login(codigo, password);

    setState(() => _isLoading = false);

    if (usuario != null) {
      final rol = usuario['Rol'];
      final nombre = usuario['Nombre'];

      if (rol == 'Programmer') {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bienvenido $nombre")),
        );
        // ignore: use_build_context_synchronously
        Navigator.pushNamed(context, '/Inicio');
      } 
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Código o contraseña incorrectos")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Inicio de Sesión", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _codigoController,
                decoration: const InputDecoration(
                  labelText: "Código de usuario",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(),
                ),
                obscureText: false,
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      child: const Text("Ingresar"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
