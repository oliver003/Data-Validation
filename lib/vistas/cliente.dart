import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/services/select_image.dart';
import 'package:flutter_application_2/services/upload_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Formatter que obliga un prefijo fijo y permite solo N dígitos después.
class PrefixDigitsFormatter extends TextInputFormatter {
  final String prefix;
  final int maxDigits;

  PrefixDigitsFormatter({required this.prefix, required this.maxDigits});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;

    if (!text.startsWith(prefix)) {
      String onlyDigits = text.replaceAll(RegExp(r'[^0-9]'), '');
      if (onlyDigits.length > maxDigits) onlyDigits = onlyDigits.substring(0, maxDigits);
      final result = prefix + onlyDigits;
      return TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }

    String suffix = text.substring(prefix.length);
    suffix = suffix.replaceAll(RegExp(r'[^0-9]'), '');
    if (suffix.length > maxDigits) suffix = suffix.substring(0, maxDigits);
    final finalText = prefix + suffix;

    int selIndex = newValue.selection.end;
    if (selIndex < prefix.length) selIndex = prefix.length;
    if (selIndex > finalText.length) selIndex = finalText.length;

    return TextEditingValue(text: finalText, selection: TextSelection.collapsed(offset: selIndex));
  }
}

class Cliente extends StatefulWidget {
  const Cliente({super.key});

  @override
  State<Cliente> createState() => _ClienteState();
}

class _ClienteState extends State<Cliente> {
  File? imagen_to_upload;
  Uint8List? webImageBytes;
  String? imageName;

  final TextEditingController N_Pedido = TextEditingController();
  final formKey = GlobalKey<FormState>();

  static const _prefix = 'PV-';

  @override
  void initState() {
    super.initState();
    N_Pedido.text = _prefix;
    N_Pedido.selection = TextSelection.collapsed(offset: _prefix.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
        backgroundColor: const Color.fromRGBO(134, 207, 61, 1),
      ),

      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(134, 207, 61, 1),   // Verde pastel
              Color.fromRGBO(248, 249, 248, 1) // Blanco suave
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Column(
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
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: (kIsWeb ? webImageBytes != null : imagen_to_upload != null)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: kIsWeb
                            ? Image.memory(webImageBytes!, fit: BoxFit.cover)
                            : Image.file(imagen_to_upload!, fit: BoxFit.cover),
                      )
                    : Column(
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

            const SizedBox(height: 20),

            Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: N_Pedido,
                    style: const TextStyle(color: Colors.black),
                    maxLength: 9,
                    inputFormatters: [
                      PrefixDigitsFormatter(prefix: _prefix, maxDigits: 6),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese el Numero de Pedido';
                      }
                      final pattern = RegExp(r'^PV-\d{6}$');
                      if (!pattern.hasMatch(value)) {
                        return 'Formato requerido: PV-123456';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: "Numero de Pedido",
                      hintText: "PV-000001",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: const Color.fromRGBO(134, 207, 61, 1), // 👈 CAMBIO
                      backgroundColor: Colors.white,                         // 👈 CAMBIO
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        if (imagen_to_upload == null && webImageBytes == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Por favor selecciona una imagen.")),
                          );
                          return;
                        }

                        try {
                          final docRef = await FirebaseFirestore.instance
                              .collection('Ilumel-Pedidos')
                              .add({
                            'N_Pedido': N_Pedido.text,
                            'Fecha': DateTime.now(),
                          });

                          final imageUrl = await uploadImage(
                            file: imagen_to_upload,
                            bytes: webImageBytes,
                            name: imageName,
                            docId: docRef.id,
                          );

                          if (imageUrl != null) {
                            await docRef.update({'imagenUrl': imageUrl});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Pedido e imagen subidos correctamente")),
                              );
                            }

                            setState(() {
                              imagen_to_upload = null;
                              webImageBytes = null;
                              N_Pedido.text = _prefix;
                              N_Pedido.selection =
                                  TextSelection.collapsed(offset: _prefix.length);
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
        ),
      ),
    );
  }
}
