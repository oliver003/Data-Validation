// ignore_for_file: file_names

import 'package:flutter/material.dart';

class Inicio extends StatelessWidget {
  const Inicio({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista con la información de cada botón
    final List<Map<String, String>> opciones = [
      {'titulo': 'Vendedor', 'ruta': '/Cliente'},
      {'titulo': 'Contable', 'ruta': '/Contable'},
      {'titulo': 'Cajera', 'ruta': '/Cajera'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromRGBO(134, 207, 61, 1),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(134, 207, 61, 1), // Verde pastel
              Color.fromRGBO(248, 249, 248, 1), // Blanco suave
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: opciones.map((opcion) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: SizedBox(
                  width: 350,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(opcion['ruta']!),
                    style: ElevatedButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 30),
                    ),
                    child: Text(opcion['titulo']!,
                    style: const TextStyle(color: Color.fromRGBO(134, 207, 61, 1) ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}