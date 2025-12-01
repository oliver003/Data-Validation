import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/main.dart' show AppData;
import 'package:flutter_application_2/services/select_image.dart';
import 'package:flutter_application_2/services/upload_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';

final String nombre = AppData.nombre;

/// Formatter que obliga un prefijo fijo y permite solo N dígitos después.
class PrefixDigitsFormatter extends TextInputFormatter {
  final String prefix;
  final int maxDigits;

  PrefixDigitsFormatter({required this.prefix, required this.maxDigits});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;

    // Si no empieza por el prefijo, reconstruimos manteniendo solo dígitos en el sufijo
    if (!text.startsWith(prefix)) {
      String onlyDigits = text.replaceAll(RegExp(r'[^0-9]'), '');
      if (onlyDigits.length > maxDigits) onlyDigits = onlyDigits.substring(0, maxDigits);
      final result = prefix + onlyDigits;
      return TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }

    // Normalizar sufijo: solo dígitos y límite de longitud
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

  // ignore: non_constant_identifier_names
  File? imagen_to_upload;
  Uint8List? webImageBytes;
  String? imageName;

  // ignore: non_constant_identifier_names
  final TextEditingController N_Pedido = TextEditingController();
  final formKey = GlobalKey<FormState>();

  static const _prefix = 'PV-';

  @override
  void initState() {
    super.initState();
    // prefijar y posicionar el cursor después del prefijo
    N_Pedido.text = _prefix;
    N_Pedido.selection = TextSelection.collapsed(offset: _prefix.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
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
                  style: const TextStyle(color: Colors.black),
                  // Limitar a 9 caracteres: 'PV-' + 6 dígitos = 9
                  maxLength: 9,
                  inputFormatters: [
                    PrefixDigitsFormatter(prefix: _prefix, maxDigits: 6),
                  ],
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese el Numero de Pedido';
                    }

                    // Requerimos el formato exacto: PV- seguido de 6 dígitos
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
                      //borderSide: BorderSide(color: Colors.blue, width: 2)
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                        final pedidoId = N_Pedido.text;

                        // 🌐 Caso móvil/web → usar Firestore plugin
                        if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
                          final docRef = FirebaseFirestore.instance
                              .collection('Ilumel-Pedidos')
                              .doc(pedidoId);

                          await docRef.set({
                            'N_Pedido': pedidoId,
                            'Fecha': DateTime.now(),
                            'Nombre': nombre,
                            'Estado': 'Enviado',
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
                                SnackBar(content: Text("Pedido e imagen subidos correctamente $nombre")),
                              );
                            }
                          }
                        }

                        // 💻 Caso Windows → usar REST API
                        else if (Platform.isWindows) {
                          const projectId = "tickets-firebase-aba0a"; // ⚠️ cambia por tu Project ID

                          // 1️⃣ Crear documento en Firestore vía REST
                          final firestoreUrl = Uri.parse(
                            "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/Ilumel-Pedidos/$pedidoId",
                          );

                          final firestoreBody = {
                            "fields": {
                              "N_Pedido": {"stringValue": pedidoId},
                              "Fecha": {"timestampValue": DateTime.now().toUtc().toIso8601String()},
                              "Nombre": {"stringValue": nombre},
                              "Estado": {"stringValue": "Enviado"},
                            }
                          };

                          final firestoreResponse = await http.patch(
                            firestoreUrl,
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode(firestoreBody),
                          );

                          if (firestoreResponse.statusCode != 200) {
                            throw Exception("Error al crear documento: ${firestoreResponse.body}");
                          }

                          // 2️⃣ Subir imagen a Storage vía REST
                          final imageUrl = await uploadImage(
                            file: imagen_to_upload,
                            bytes: webImageBytes,
                            name: imageName,
                            docId: pedidoId,
                          );

                          // 3️⃣ Actualizar documento con la URL
                          if (imageUrl != null) {
                            final updateBody = {
                              "fields": {
                                "imagenUrl": {"stringValue": imageUrl}
                              }
                            };

                            final updateResponse = await http.patch(
                              firestoreUrl,
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode(updateBody),
                            );

                            if (updateResponse.statusCode != 200) {
                              throw Exception("Error al actualizar documento: ${updateResponse.body}");
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Pedido e imagen subidos correctamente $nombre")),
                              );
                            }
                          }
                        }

                        // Opcional: limpiar formulario
                        setState(() {
                          imagen_to_upload = null;
                          webImageBytes = null;
                          N_Pedido.text = _prefix;
                          N_Pedido.selection = TextSelection.collapsed(offset: _prefix.length);
                        });
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
                )
              ],
            ),
          ),
        ],
      )
    ));
  }
}