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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // Fondo degradado verde pastel
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromRGBO(134, 207, 61, 1),
                    Color.fromRGBO(248, 249, 248, 1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              width: double.infinity,
              height: size.height * 0.4,
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 20),
                child: Image.asset("lib/vistas/assets/img/hola.png",
                width: 250,
                height: 250,
                fit: BoxFit.contain,
                ),
              ),
            ),
            // Contenido del login
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Inicio de Sesión",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _codigoController,
                      decoration: const InputDecoration(
                        labelText: "Código de usuario",
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Color.fromRGBO(134, 207, 61, 1))
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color.fromRGBO(134, 207, 61, 1))
                        )
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: "Contraseña",
                        border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color.fromRGBO(134, 207, 61, 1))),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color.fromRGBO(134, 207, 61, 1))
                        )
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(134, 207, 61, 1)),
                        )
                        :// 🔽🔽🔽 AQUÍ SE HIZO EL CAMBIO (BOTÓN CON SOMBRA) 🔽🔽🔽
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 11,
                                offset: Offset(0, 5),
                              ),
                            ],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromRGBO(134, 207, 61, 1),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(200, 60),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0, // importante para evitar doble sombra
                            ),
                            onPressed: _login,
                            child: const Text(
                              "Ingresar",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                  ]      //  
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
