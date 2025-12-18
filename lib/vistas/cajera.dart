import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_2/main.dart' show AppData;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

final String nombre = AppData.nombre;

class Cajera extends StatefulWidget {
  const Cajera({super.key});

  @override
  State<Cajera> createState() => _CajeraState();
}

class _CajeraState extends State<Cajera> {
  String? pedidoSeleccionado;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transacciones Confirmadas"),
       flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
              Color.fromRGBO(134, 207, 61, 1), 
              Colors.white,                  
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,)
        ),
        width: double.infinity,
        height: kToolbarHeight * 4,
       ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(248, 249, 248, 1),
              Color.fromRGBO(134, 207, 61, 0.08),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _buildMobileWebView(),
        ),
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = MediaQuery.of(context).size.width < 480;
          return isCompact
              ? FloatingActionButton(
                  onPressed: _mostrarHistorialConsumidos,
                  backgroundColor: const Color.fromRGBO(134, 207, 61, 1),
                  tooltip: 'Historial',
                  child: const Icon(Icons.history, color: Colors.white),
                )
              : FloatingActionButton.extended(
                  onPressed: _mostrarHistorialConsumidos,
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

  Widget _buildMobileWebView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Ilumel-Pedidos')
          .where('Estado', isEqualTo: 'Confirmado')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error al cargar los datos."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No hay pedidos confirmados."));
        }

        final docs = snapshot.data!.docs;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final imagenUrl = data["imagenUrl"] ?? "";

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        title: Text("Pedido #${data['N_Pedido'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Cliente: ${data['Nombre'] ?? 'N/A'}"),

                        leading: Radio<String>(
                          value: docId,
                          groupValue: pedidoSeleccionado,
                          onChanged: (value) {
                            setState(() => pedidoSeleccionado = value);
                          },
                        ),

                        trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (imagenUrl.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.image, color: Colors.blue),
                              onPressed: () {
                                mostrarImagen(context, imagenUrl);
                              },
                            ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == "datos") {
                                mostrarDatosPedido(context, data);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: "datos",
                                child: Text("Datos"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    );
                  },
                ),
              ),

              _buildActionButtons(),
            ],
          );
        },
      );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          SizedBox(
            width: 140,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: pedidoSeleccionado == null ? null : _showConsumirConfirmDialog,
              child: const Text("Consumir"),
            ),
          ),
          SizedBox(
            width: 140,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: pedidoSeleccionado == null ? null : _compartirComoPDF,
              label: const Text("Compartir"),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== COMPARTIR COMO PDF ====================
  Future<void> _compartirComoPDF() async {
    if (pedidoSeleccionado == null) return;

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generando PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Obtener datos del pedido
      final doc = await FirebaseFirestore.instance
          .collection('Ilumel-Pedidos')
          .doc(pedidoSeleccionado)
          .get();
      final datosPedido = doc.data();
      
      if (datosPedido == null) {
        throw Exception('No se encontraron datos del pedido');
      }

      // Generar PDF
      final pdfBytes = await _generarPDF(datosPedido);

      if (mounted) {
        Navigator.pop(context); // Cerrar loading

        // Compartir/Descargar PDF
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Pedido_${datosPedido['N_Pedido']}.pdf',
        );

        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ PDF generado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<Uint8List> _generarPDF(Map<String, dynamic> datos) async {
    final pdf = pw.Document();
    final DateFormat formato = DateFormat("dd/MM/yyyy hh:mm a");

    String formatear(dynamic valor) {
      if (valor is Timestamp) {
        return formato.format(valor.toDate());
      }
      if (valor is String) {
        try {
          final dt = DateTime.parse(valor);
          return formato.format(dt);
        } catch (_) {}
      }
      return valor?.toString() ?? "";
    }

    // Descargar imagen si existe
    pw.ImageProvider? imagenComprobante;
    final imagenUrl = datos['imagenUrl']?.toString() ?? '';
    
    if (imagenUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imagenUrl));
        if (response.statusCode == 200) {
          imagenComprobante = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        // ignore: avoid_print
        print('Error al descargar imagen: $e');
      }
    }

    // Crear PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ENCABEZADO
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  gradient: const pw.LinearGradient(
                    colors: [
                      PdfColor.fromInt(0xFF86CF3D),
                      PdfColor.fromInt(0xFF6FB82E),
                    ],
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DETALLES DEL PEDIDO',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Pedido #${datos['N_Pedido'] ?? 'N/A'}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // INFORMACIÓN DEL PEDIDO
              _buildCampoPDF('Número de Pedido', datos['N_Pedido']),
              _buildCampoPDF('Cliente', datos['Nombre']),
              _buildCampoPDF('Fecha del Pedido', formatear(datos['Fecha'])),
              
              if (datos['ConfirmadoPor'] != null)
                _buildCampoPDF('Confirmado por', datos['ConfirmadoPor']),
              
              if (datos['FechaConfirmado'] != null)
                _buildCampoPDF('Fecha de Confirmación', formatear(datos['FechaConfirmado'])),
              
              if (datos['Banco'] != null)
                _buildCampoPDF('Banco', datos['Banco']),
              
              if (datos['NumeroAprobacion'] != null)
                _buildCampoPDF('Número de Aprobación', datos['NumeroAprobacion']),
              
              _buildCampoPDF('Estado', datos['Estado']),

              pw.SizedBox(height: 20),

              // IMAGEN DEL COMPROBANTE
              if (imagenComprobante != null) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'COMPROBANTE DE PAGO',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF86CF3D),
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Center(
                        child: pw.Image(
                          imagenComprobante,
                          height: 300,
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              pw.Spacer(),

              // PIE DE PÁGINA
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generado el ${formato.format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildCampoPDF(String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(
          left: pw.BorderSide(
            color: const PdfColor.fromInt(0xFF86CF3D),
            width: 3,
          ),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value.toString(),
            style: const pw.TextStyle(
              fontSize: 13,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showConsumirConfirmDialog() {
    if (pedidoSeleccionado == null) return;
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header con icono y gradiente suave
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color.fromRGBO(134, 207, 61, 1),
                      Color.fromRGBO(111, 184, 46, 1),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Confirmar Consumo',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Contenido
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.receipt_long, color: Color.fromRGBO(134, 207, 61, 1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¿Deseas marcar el pedido $pedidoSeleccionado como consumido? Esta acción no se puede deshacer.',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancelar',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _consumirPedido();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(134, 207, 61, 1),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Consumir',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _consumirPedido() async {
    if (pedidoSeleccionado == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('Ilumel-Pedidos')
          .doc(pedidoSeleccionado)
          .update({
        'Estado': 'Consumido',
        'FechaConsumo': DateTime.now(),
        'ConsumidoPor': nombre,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pedido marcado como consumido."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void mostrarDatosPedido(BuildContext context, Map<String, dynamic> data) {
    final DateFormat formato = DateFormat("dd/MM/yyyy hh:mm a");

    String formatear(dynamic valor) {
      if (valor is Timestamp) {
        return formato.format(valor.toDate());
      }
      if (valor is String) {
        try {
          final dt = DateTime.parse(valor);
          return formato.format(dt);
        } catch (_) {
          return valor;
        }
      }
      return valor?.toString() ?? "";
    }

    final Map<String, dynamic> datos = Map.of(data);
    datos.remove("imagenUrl");

    datos["Fecha"] = formatear(datos["Fecha"]);
    datos["FechaConfirmado"] = formatear(datos["FechaConfirmado"]);
    datos["FechaConsumo"] = formatear(datos["FechaConsumo"]);

    final List<String> orden = [
      "N_Pedido",
      "Nombre",
      "Fecha",
      "ConfirmadoPor",
      "FechaConfirmado",
      "ConsumidoPor",
      "FechaConsumo",
      "Banco",
      "NumeroAprobacion",
      "Estado",
    ];

    final Map<String, String> nombresBonitos = {
      "N_Pedido": "Número de Pedido",
      "Nombre": "Cliente",
      "Fecha": "Fecha del Pedido",
      "ConfirmadoPor": "Confirmado por",
      "FechaConfirmado": "Fecha de Confirmación",
      "ConsumidoPor": "Consumido por",
      "FechaConsumo": "Fecha de Consumo",
      "Banco": "Banco",
      "NumeroAprobacion": "Número de Aprobación",
      "Estado": "Estado",
    };

    final Map<String, dynamic> datosOrdenados = {};

    for (var campo in orden) {
      if (datos.containsKey(campo)) {
        datosOrdenados[campo] = datos[campo];
        datos.remove(campo);
      }
    }

    datosOrdenados.addAll(datos);

    final camposFiltrados = datosOrdenados.entries.where((entry) {
      final valor = entry.value;

      if (valor == null) return false;
      if (valor.toString().trim().isEmpty) return false;
      if (valor.toString().trim().toLowerCase() == "null") return false;

      return true;
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Datos del pedido"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: camposFiltrados.map((entry) {
                final key = nombresBonitos[entry.key] ?? entry.key;
                final value = entry.value?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: "$key: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: value),
                      ],
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.close, size: 18),
              label: const Text("Cerrar"),
            )
          ],
        );
      },
    );
  }

  void mostrarImagen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: InteractiveViewer(
            child: Image.network(url),
          ),
        );
      },
    );
  }

  // ==================== HISTORIAL DE CONSUMIDOS ====================
  void _mostrarHistorialConsumidos() {
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
                final maxHeight = constraints.maxHeight;
                final maxWidth = constraints.maxWidth;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                    maxWidth: maxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ENCABEZADO
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
                              Icon(Icons.remove_shopping_cart, color: Colors.white, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Pedidos Consumidos',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // LISTA DE PEDIDOS CONSUMIDOS con Flexible para evitar overflow
                        Flexible(
                          child: _buildHistorialConsumidosMobileWeb(),
                        ),

                        // BOTÓN CERRAR
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

  Widget _buildHistorialConsumidosMobileWeb() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Ilumel-Pedidos')
          .where('Estado', isEqualTo: 'Consumido')
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
                Text(
                  'No hay pedidos consumidos',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
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
            'ConsumidoPor': data['ConsumidoPor'] ?? 'Desconocido',
            'FechaConsumo': data['FechaConsumo'],
            'FechaConfirmado': data['FechaConfirmado'],
            'ConfirmadoPor': data['ConfirmadoPor'] ?? 'N/A',
            'Banco': data['Banco'] ?? 'N/A',
            'NumeroAprobacion': data['NumeroAprobacion'] ?? 'N/A',
          };
        }).toList();

        // Ordenar por FechaConsumo descendente
        pedidos.sort((a, b) {
          final fechaA = a['FechaConsumo'];
          final fechaB = b['FechaConsumo'];

          if (fechaA == null && fechaB == null) return 0;
          if (fechaA == null) return 1;
          if (fechaB == null) return -1;

          DateTime dateA = fechaA is Timestamp ? fechaA.toDate() : DateTime.parse(fechaA.toString());
          DateTime dateB = fechaB is Timestamp ? fechaB.toDate() : DateTime.parse(fechaB.toString());

          return dateB.compareTo(dateA);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pedidos.length,
          itemBuilder: (context, index) {
            final pedido = pedidos[index];

            String fechaFormateada = 'N/A';
            if (pedido['FechaConsumo'] != null) {
              if (pedido['FechaConsumo'] is Timestamp) {
                fechaFormateada = DateFormat("dd/MM/yyyy hh:mm a").format((pedido['FechaConsumo'] as Timestamp).toDate());
              } else {
                try {
                  fechaFormateada = DateFormat("dd/MM/yyyy hh:mm a").format(DateTime.parse(pedido['FechaConsumo'].toString()));
                } catch (_) {
                  fechaFormateada = pedido['FechaConsumo'].toString();
                }
              }
            }

            String fechaConfirmadoFormateada = 'N/A';
            if (pedido['FechaConfirmado'] != null) {
              if (pedido['FechaConfirmado'] is Timestamp) {
                fechaConfirmadoFormateada = DateFormat("dd/MM/yyyy hh:mm a").format((pedido['FechaConfirmado'] as Timestamp).toDate());
              } else {
                try {
                  fechaConfirmadoFormateada = DateFormat("dd/MM/yyyy hh:mm a").format(DateTime.parse(pedido['FechaConfirmado'].toString()));
                } catch (_) {
                  fechaConfirmadoFormateada = pedido['FechaConfirmado'].toString();
                }
              }
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(134, 207, 61, 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.remove_shopping_cart,
                    color: Color.fromRGBO(134, 207, 61, 1),
                  ),
                ),
                  title: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Pedido #', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '${pedido['N_Pedido']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                subtitle: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Cliente: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: '${pedido['Nombre']}'),
                    ],
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Consumido por: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: '${pedido['ConsumidoPor'] ?? 'N/A'}'),
                            ],
                          ),
                          style: const TextStyle(color: Colors.green),
                        ),
                        const SizedBox(height: 8),
                        Text.rich(TextSpan(children: [
                          const TextSpan(text: 'Fecha de Consumo: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: fechaFormateada),
                        ])),
                        Text.rich(TextSpan(children: [
                          const TextSpan(text: 'Confirmado por: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: '${pedido['ConfirmadoPor'] ?? 'N/A'}'),
                        ])),
                        Text.rich(TextSpan(children: [
                          const TextSpan(text: 'Fecha de Confirmación: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: fechaConfirmadoFormateada),
                        ])),
                        Text.rich(TextSpan(children: [
                          const TextSpan(text: 'Banco: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: '${pedido['Banco']}'),
                        ])),
                        Text.rich(TextSpan(children: [
                          const TextSpan(text: 'Número de aprobación: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: '${pedido['NumeroAprobacion']}'),
                        ])),
                        const SizedBox(height: 12),
                        if (pedido['imagenUrl'] != null && (pedido['imagenUrl'] as String).isNotEmpty)
                          GestureDetector(
                            onTap: () => mostrarImagen(context, pedido['imagenUrl'] as String),
                            child: Row(
                              children: [
                                Image.network(
                                  pedido['imagenUrl'] as String,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Imagen consumida', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      const Text('Pulsa la miniatura para ver en grande', style: TextStyle(color: Colors.grey)),
                                    ],
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
      },
    );
  }

}