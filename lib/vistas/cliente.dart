import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/main.dart' show AppData;
import 'package:flutter_application_2/services/select_image.dart';
import 'package:flutter_application_2/services/upload_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

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
                    } else {
                      // Puede ser cancelación o tamaño > 10 MB
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Imagen no seleccionada o excede los 10 MB.'),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    constraints: const BoxConstraints(
                      maxHeight: 400,
                      minHeight: 100,
                      minWidth: 200,
                    ),
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
                            child: InteractiveViewer(
                              panEnabled: true,
                              boundaryMargin: const EdgeInsets.all(8),
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: kIsWeb
                                  ? Image.memory(
                                      webImageBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )
                                  : Image.file(
                                      imagen_to_upload!,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          )
                        : SizedBox(
                            height: 220,
                            width: double.infinity,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo, size: 60, color: Colors.blueAccent),
                                  SizedBox(height: 10),
                                  Text(
                                    "Toca para seleccionar una imagen \n (Máximo 10 MB).",
                                    style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                                  ),
                                ],
                              ),
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
                  onPressed: _mostrarHistorialConfirmados,
                  backgroundColor: const Color.fromRGBO(134, 207, 61, 1),
                  tooltip: 'Historial',
                  child: const Icon(Icons.history, color: Colors.white),
                )
              : FloatingActionButton.extended(
                  onPressed: _mostrarHistorialConfirmados,
                  backgroundColor: const Color.fromRGBO(134, 207, 61, 1),
                  icon: const Icon(Icons.history, color: Colors.white),
                  label: const Text(
                    'Historial',
                    style: TextStyle(color: Colors.white),
                  ),
                );
        },
      ),
    );
  }

  // ==================== MOSTRAR HISTORIAL DE CONFIRMADOS ====================
  void _mostrarHistorialConfirmados() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = constraints.maxHeight > 600 ? 600.0 : constraints.maxHeight * 0.98;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 500,
                    maxHeight: maxHeight,
                    minWidth: 260,
                    minHeight: 200,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Historial de tus pedidos',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: (maxHeight - 160).clamp(120, 400),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildHistorialMobileWeb(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistorialMobileWeb() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
          .collection('Ilumel-Pedidos')
          .where('Nombre', isEqualTo: nombre)
          .orderBy('Fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No tienes pedidos enviados', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        final pedidos = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'N_Pedido': data['N_Pedido'] ?? 'N/A',
            'Nombre': data['Nombre'] ?? 'Sin nombre',
            'imagenUrl': data['imagenUrl'] ?? '',
            'Fecha': data['Fecha'],
            'Estado': data['Estado'] ?? 'N/A',
          };
        }).toList();

        pedidos.sort((a, b) {
          final fechaA = a['Fecha'];
          final fechaB = b['Fecha'];
          if (fechaA == null && fechaB == null) return 0;
          if (fechaA == null) return 1;
          if (fechaB == null) return -1;
          DateTime dateA = fechaA is Timestamp ? fechaA.toDate() : DateTime.tryParse(fechaA.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
          DateTime dateB = fechaB is Timestamp ? fechaB.toDate() : DateTime.tryParse(fechaB.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });

        return _buildListaConfirmados(pedidos);
      },
    );
  }

  Widget _buildListaConfirmados(List<Map<String, dynamic>> pedidos) {
    final DateFormat formato = DateFormat("dd/MM/yyyy hh:mm a");

    return ListView.builder(
      itemCount: pedidos.length,
      itemBuilder: (context, index) {
        final pedido = pedidos[index];

        String fechaFormateada = 'N/A';
        final fecha = pedido['Fecha'];
        if (fecha != null) {
          try {
            if (fecha is Timestamp) {
              fechaFormateada = formato.format(fecha.toDate());
            } else if (fecha is String) {
              fechaFormateada = formato.format(DateTime.parse(fecha));
            } else {
              fechaFormateada = formato.format(DateTime.parse(fecha.toString()));
            }
          } catch (_) {}
        }

        // Estado como string para usar en chip/cuadro
        final String estadoStr = (pedido['Estado'] ?? 'N/A').toString();

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(134, 207, 61, 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color.fromRGBO(134, 207, 61, 1),
              ),
            ),
            title: Tooltip(
              message: 'Pedido #${pedido['N_Pedido']}',
              child: Text(
                'Pedido #${pedido['N_Pedido']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                softWrap: true,
                maxLines: 2,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Tooltip(
                        message: 'Cliente: ${pedido['Nombre']}',
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Cliente: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: '${pedido['Nombre']}'),
                            ],
                          ),
                          style: const TextStyle(fontSize: 14),
                          softWrap: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetalleFila('Fecha de Envío', fechaFormateada),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 120,
                          child: Text(
                            'Estado:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              // ignore: deprecated_member_use
                              color: _estadoColor(estadoStr).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(6),
                              // ignore: deprecated_member_use
                              border: Border.all(color: _estadoColor(estadoStr).withOpacity(0.35)),
                            ),
                            child: Text(
                              estadoStr,
                              style: TextStyle(
                                color: _estadoColor(estadoStr),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (pedido['imagenUrl'] != null && (pedido['imagenUrl'] as String).isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              child: InteractiveViewer(
                                child: Image.network(pedido['imagenUrl'] as String),
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[200],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                pedido['imagenUrl'] as String,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Toca para ver la imagen.',
                                style: TextStyle(color: Colors.blueGrey),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetalleFila(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Color _estadoColor(String estado) {
    final e = estado.toLowerCase();
    if (e.contains('confirmado')) return const Color(0xFF2E7D32); // verde
    if (e.contains('enviado')) return const Color(0xFF1565C0); // azul
    if (e.contains('consumido')) return const Color(0xFF616161); // gris
    //if (e.contains('rechaz')) return const Color(0xFFC62828); // rojo
    return const Color(0xFF6D4C41); // marrón por defecto
  }

}