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
  bool _isUploading = false;
  // Pedidos del usuario
  List<Map<String, dynamic>> _myPedidos = [];
  String? _selectedPedidoId;
  bool _loadingPedidos = false;

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
    // Cargar pedidos del usuario al iniciar
    _loadMyPedidos();
  }

  Future<void> _loadMyPedidos() async {
    setState(() {
      _loadingPedidos = true;
    });

    try {
      List<Map<String, dynamic>> items = [];

      // Móvil/Web con el plugin de Firestore
      if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
        final snapshot = await FirebaseFirestore.instance
            .collection('Ilumel-Pedidos')
            .where('Nombre', isEqualTo: nombre)
            .orderBy('Fecha', descending: true)
            .get();

        items = snapshot.docs.map((d) {
          final data = d.data();
          final fecha = data['Fecha'];
          String fechaStr = '';
          try {
            if (fecha != null) {
              // Timestamp -> DateTime
              if (fecha is Timestamp) {
                fechaStr = fecha.toDate().toString();
              } else {
                fechaStr = fecha.toString();
              }
            }
          } catch (_) {}

          return {
            'id': d.id,
            'N_Pedido': data['N_Pedido'] ?? d.id,
            'Fecha': fechaStr,
            'Estado': data['Estado'] ?? '',
            'imagenUrl': data['imagenUrl'],
          };
        }).toList();
      }

      // Windows (REST)
      else if (Platform.isWindows) {
        const projectId = "tickets-firebase-aba0a"; // mismo que en otras operaciones
        final url = Uri.parse(
          'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/Ilumel-Pedidos',
        );

        final resp = await http.get(url);
        if (resp.statusCode == 200) {
          final jsonBody = jsonDecode(resp.body);
          final docs = jsonBody['documents'] as List<dynamic>? ?? [];
          for (final doc in docs) {
            final fields = doc['fields'] as Map<String, dynamic>? ?? {};
            final nombreField = fields['Nombre']?['stringValue'];
            if (nombreField == nombre) {
              final nPedido = fields['N_Pedido']?['stringValue'] ?? '';
              final fecha = fields['Fecha']?['timestampValue'] ?? '';
              final estado = fields['Estado']?['stringValue'] ?? '';
              final imagenUrl = fields['imagenUrl']?['stringValue'];
              // extraer id del nombre del documento
              final name = doc['name'] as String? ?? '';
              final id = name.split('/').isNotEmpty ? name.split('/').last : name;
              items.add({
                'id': id,
                'N_Pedido': nPedido.isNotEmpty ? nPedido : id,
                'Fecha': fecha,
                'Estado': estado,
                'imagenUrl': imagenUrl,
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _myPedidos = items;
          // si no hay seleccion previa, dejar null
          if (_myPedidos.isNotEmpty && _selectedPedidoId == null) {
            _selectedPedidoId = _myPedidos.first['id'] as String?;
          }
        });
      }
    } catch (e) {
      // si ocurre un error, mantener la lista vacía y mostrar por consola
      debugPrint('Error cargando pedidos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingPedidos = false;
        });
      }
    }
  }

  // ignore: unused_element
  Widget _buildPedidosContent(BuildContext ctx) {
    if (_loadingPedidos) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: const [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Cargando pedidos...'),
          ],
        ),
      );
    }

    if (_myPedidos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: const Text('No hay pedidos subidos aún.', style: TextStyle(color: Colors.black54)),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tus pedidos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ..._myPedidos.map((p) {
              final id = p['id']?.toString() ?? '';
              final label = p['N_Pedido']?.toString() ?? id;
              final fecha = p['Fecha']?.toString() ?? '';
              return Card(
                child: ListTile(
                  title: Text(label),
                  subtitle: Text('Fecha: $fecha'),
                  onTap: () {
                    setState(() {
                      _selectedPedidoId = id;
                    });
                    Navigator.of(ctx).pop();
                  },
                ),
              );
            }),
            if (_selectedPedidoId != null) ...[
              const SizedBox(height: 12),
              const Text('Seleccionado:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final sel = _myPedidos.firstWhere((e) => e['id'] == _selectedPedidoId, orElse: () => {});
                if (sel.isEmpty) return const SizedBox.shrink();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pedido: ${sel['N_Pedido'] ?? sel['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('Fecha: ${sel['Fecha'] ?? ''}'),
                      ],
                    ),
                  ),
                );
              })
            ]
          ],
        ),
      ),
    );
  }

  void _showHistorial() {
    // refrescar antes de mostrar
    _loadMyPedidos().then((_) {
      showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (BuildContext ctx) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Encabezado con gradiente
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromRGBO(134, 207, 61, 1),
                          Color.fromRGBO(111, 184, 46, 1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.history, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Historial de Pedidos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lista expandida
                  Expanded(child: _buildHistorialList(ctx)),

                  // Botón Cerrar con estilo similar al de contable.dart
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildHistorialList(BuildContext ctx) {
    if (_loadingPedidos) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [CircularProgressIndicator(), SizedBox(height: 8), Text('Cargando pedidos...')],
        ),
      );
    }

    if (_myPedidos.isEmpty) {
      return const Center(child: Text('No hay pedidos subidos aún.', style: TextStyle(color: Colors.black54)));
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _myPedidos.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = _myPedidos[index];
        final id = p['id']?.toString() ?? '';
        final label = p['N_Pedido']?.toString() ?? id;
        final fecha = p['Fecha']?.toString() ?? '';
        final estado = p['Estado']?.toString() ?? '';
        final imagenUrl = p['imagenUrl'] as String?;

        Color chipColor;
        if (estado.toLowerCase().contains('enviado')) {
          chipColor = Colors.green;
        } else if (estado.toLowerCase().contains('confirmado')) {
          chipColor = Colors.blue;
        } else {
          chipColor = Colors.red;
        }

        return ListTile(
          leading: imagenUrl != null && imagenUrl.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    showDialog(
                      context: ctx,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.network(
                            imagenUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 240,
                              height: 240,
                              child: Center(child: Icon(Icons.broken_image, size: 48)),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Image.network(
                    imagenUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                  ),
                )
              : const SizedBox(width: 56, height: 56, child: Icon(Icons.image_not_supported)),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Fecha: $fecha'),
          trailing: Chip(label: Text(estado.isNotEmpty ? estado : 'Desconocido', style: const TextStyle(color: Colors.white)), backgroundColor: chipColor),
          onTap: () {
            // Seleccionar el pedido y cerrar el diálogo (comportamiento previo)
            setState(() {
              _selectedPedidoId = id;
            });
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Text('Envio de Confirmación - $nombre'),
        //backgroundColor: const Color.fromRGBO(134, 207, 61, 1),
        backgroundColor: Colors.transparent, 
        elevation: 0, 
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
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
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
                    // Limitar a 10 caracteres: 'PV-' + 7 dígitos = 10
                    maxLength: 10,
                    inputFormatters: [
                      PrefixDigitsFormatter(prefix: _prefix, maxDigits: 7),
                    ],
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese el Numero de Pedido';
                      }

                      // Requerimos el formato exacto: PV- seguido de 7 dígitos
                        final pattern = RegExp(r'^PV-\d{7}$');
                      if (!pattern.hasMatch(value)) {
                        return 'Formato requerido: PV-1234567';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: "Numero de Pedido",
                      hintText: "PV-0000001",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        //borderSide: BorderSide(color: Colors.blue, width: 2)
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    )
                  ),
                
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _isUploading ? null : () async {
                      if (formKey.currentState!.validate()) {
                        if (imagen_to_upload == null && webImageBytes == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Por favor selecciona una imagen.")),
                          );
                          return;
                        }

                        setState(() {
                          _isUploading = true;
                        });

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
                                  SnackBar(
                                    content: Text("Pedido e imagen subidos correctamente, $nombre"),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                              // refrescar lista de pedidos del usuario
                              await _loadMyPedidos();
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
                                // refrescar lista de pedidos del usuario
                                await _loadMyPedidos();
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
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isUploading = false;
                            });
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Por favor complete todos los campos.")),
                        );
                      }
                    },
                    child: _isUploading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text("Subiendo..."),
                            ],
                          )
                        : const Text("Subir a Base de Datos"),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    ), 
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = MediaQuery.of(context).size.width < 480;
          return isCompact
              ? FloatingActionButton(
                  onPressed: _showHistorial,
                  backgroundColor: const Color.fromRGBO(134, 207, 61, 1),
                  tooltip: 'Historial',
                  child: const Icon(Icons.history, color: Colors.white),
                )
              : FloatingActionButton.extended(
                  onPressed: _showHistorial,
                  backgroundColor: const Color.fromRGBO(134, 207, 61, 1),
                  icon: const Icon(Icons.history, color: Colors.white),
                  label: const Text('Historial', style: TextStyle(color: Colors.white)),
                );
        },
      ),
    );
  }
}