import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/services/select_image.dart';
import 'package:flutter_application_2/services/upload_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class Cliente extends StatefulWidget {
  const Cliente({super.key});

  @override
  State<Cliente> createState() => _ClienteState();
}

class _ClienteState extends State<Cliente> {

  // ignore: non_constant_identifier_names
  File? imagen_to_upload;
  Uint8List? webImageBytes;
  String? imageName;

  // ignore: non_constant_identifier_names
  final TextEditingController N_Pedido = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final imagen = await getImage();
              if (imagen != null) {
                setState(() {
                  imageName = imagen.name;
                  if (kIsWeb) {
                    webImageBytes = imagen.bytes;
                  } else {
                    imagen_to_upload = File(imagen.xfile!.path);
                  }
                });
              }
            },
            child: Container(
              margin: const EdgeInsets.all(16),
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: (kIsWeb ? webImageBytes != null : imagen_to_upload != null)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: kIsWeb
                        ? Image.memory(
                            webImageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Image.file(
                            imagen_to_upload!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_a_photo, size: 60, color: Colors.blueAccent),
                        SizedBox(height: 10),
                        Text(
                          "Toca para seleccionar una imagen",
                          style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
          
          const SizedBox(height: 20),
          Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField (
                  controller: N_Pedido,
                  style: TextStyle(color: Colors.black),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el Numero de Pedido'; // Texto del mensaje de error
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: "Numero de Pedido",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      //borderSide: BorderSide(color: Colors.blue, width: 2)
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  )
                ),
              
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      if (imagen_to_upload == null && webImageBytes == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Por favor selecciona una imagen.")),
                        );
                        return;
                      }

                      try {
                        // 1️⃣ Crear documento con los datos básicos
                        final docRef = await FirebaseFirestore.instance
                            .collection('Ilumel-Pedidos')
                            .add({
                          'N_Pedido': N_Pedido.text,
                          'Fecha': DateTime.now(),
                        });

                        // 2️⃣ Subir imagen vinculada con el ID del documento
                        final imageUrl = await uploadImage(
                          file: imagen_to_upload,
                          bytes: webImageBytes,
                          name: imageName,
                          docId: docRef.id,
                        );

                        if (imageUrl != null) {
                          // 3️⃣ Guardar la URL dentro del mismo documento
                          await docRef.update({'imagenUrl': imageUrl});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Pedido e imagen subidos correctamente")),
                            );
                          }
                          // Opcional: limpiar formulario
                          setState(() {
                            imagen_to_upload = null;
                            webImageBytes = null;
                            N_Pedido.clear();
                          });
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Error al subir la imagen.")),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error al guardar datos: $e")),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Por favor complete todos los campos.")),
                      );
                    }
                  },
                  child: const Text("Subir a Base de Datos"),
                ),
              ],
            ),
          ),
        ],
      )
    );
  }
}