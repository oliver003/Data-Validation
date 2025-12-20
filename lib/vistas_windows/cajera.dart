import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart' show AppData;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

final String nombre = AppData.nombre;

class CajeraWindows extends StatefulWidget {
  const CajeraWindows({super.key});

  @override
  State<CajeraWindows> createState() => _CajeraWindowsState();
}

class _CajeraWindowsState extends State<CajeraWindows> {
  String? pedidoSeleccionado;
  List<Map<String, dynamic>> _pedidos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPedidosREST();
    Future.delayed(const Duration(seconds: 5), _startPolling);
  }

  void _startPolling() {
    if (!mounted) return;
    Future.delayed(const Duration(seconds: 5), () {
      _loadPedidosREST();
      _startPolling();
    });
  }

  Future<void> _loadPedidosREST() async {
    try {
      const projectId = "tickets-firebase-aba0a";
      final url = Uri.parse(
        "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery",
      );

      final queryBody = {
        "structuredQuery": {
          "from": [{"collectionId": "Ilumel-Pedidos"}],
          "where": {
            "fieldFilter": {
              "field": {"fieldPath": "Estado"},
              "op": "EQUAL",
              "value": {"stringValue": "Confirmado"}
            }
          }
        }
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(queryBody),
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        final pedidos = <Map<String, dynamic>>[];

        for (var result in results) {
          if (result['document'] != null) {
            final doc = result['document'];
            final fields = doc['fields'] as Map<String, dynamic>;

            pedidos.add({
              'Nombre': fields['Nombre']?['stringValue'] ?? 'N/A',
              'N_Pedido': fields['N_Pedido']?['stringValue'] ?? 'N/A',
              'imagenUrl': fields['imagenUrl']?['stringValue'] ?? '',
              'ConfirmadoPor': fields['ConfirmadoPor']?['stringValue'],
              'Banco': fields['Banco']?['stringValue'],
              'NumeroAprobacion': fields['NumeroAprobacion']?['stringValue'],
              'Estado': fields['Estado']?['stringValue'],
              'Fecha': fields['Fecha']?['timestampValue'],
              'FechaConfirmado': fields['FechaConfirmado']?['timestampValue'],
              'FechaConsumo': fields['FechaConsumo']?['timestampValue'],
              'ConsumidoPor': fields['ConsumidoPor']?['stringValue'],
            });
          }
        }

        if (mounted) {
          setState(() {
            _pedidos = pedidos;
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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
          child: _buildWindowsView(),
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

  Widget _buildWindowsView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_pedidos.isEmpty) {
      return const Center(child: Text("No hay pedidos confirmados."));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _pedidos.length,
            itemBuilder: (context, index) {
              final data = _pedidos[index];
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
                    value: data['N_Pedido'],
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
      final datosPedido = _pedidos.firstWhere(
        (p) => p['id'] == pedidoSeleccionado,
        orElse: () => {},
      );

      if (datosPedido.isEmpty) {
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
      if (valor is String) {
        try {
          final dt = DateTime.parse(valor).toLocal();
          return formato.format(dt);
        } catch (_) {
          return valor;
        }
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
    
    final match = _pedidos.firstWhere(
      (p) => p['id'] == pedidoSeleccionado,
      orElse: () => {},
    );
    final pedidoNumero = match['N_Pedido'] ?? pedidoSeleccionado!;
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 420,
            minWidth: 300,
          ),
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
                        '¿Deseas marcar el pedido $pedidoNumero como consumido? Esta acción no se puede deshacer.',
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
      ),
    );
  }

  Future<void> _consumirPedido() async {
    if (pedidoSeleccionado == null) return;

    try {
      const projectId = "tickets-firebase-aba0a";
      final firestoreUrl = Uri.parse(
        "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/Ilumel-Pedidos/$pedidoSeleccionado?updateMask.fieldPaths=Estado&updateMask.fieldPaths=FechaConsumo&updateMask.fieldPaths=ConsumidoPor",
      );

      final updateBody = {
        "fields": {
          "Estado": {"stringValue": "Consumido"},
          "FechaConsumo": {
            "timestampValue": DateTime.now().toUtc().toIso8601String()
          },
          "ConsumidoPor": {"stringValue": nombre},
        }
      };

      final response = await http.patch(
        firestoreUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(updateBody),
      );

      if (response.statusCode != 200) {
        throw Exception("Error al actualizar documento: ${response.body}");
      }

      if (mounted) {
        _loadPedidosREST();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pedido marcado como consumido ✓"),
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
      if (valor is String) {
        try {
          final dt = DateTime.parse(valor).toLocal();
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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: 600,
                minWidth: 260,
                minHeight: 200,
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
                          Icon(Icons.check_circle, color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pedidos Consumidos',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // LISTA DE PEDIDOS CONSUMIDOS
                    SizedBox(
                      height: 300,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildHistorialConsumidosWindows(),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistorialConsumidosWindows() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadConsumidosREST(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

        final pedidos = snapshot.data!;
        return _buildListaConsumidos(pedidos);
      },
    );
  }

  Widget _buildListaConsumidos(List<Map<String, dynamic>> pedidos) {
    final DateFormat formato = DateFormat("dd/MM/yyyy hh:mm a");

    return ListView.builder(
      itemCount: pedidos.length,
      itemBuilder: (context, index) {
        final pedido = pedidos[index];
        
        String fechaFormateada = 'N/A';
        String fechaConfirmadaFormateada = 'N/A';
        if (pedido['FechaConsumo'] != null) {
          if (pedido['FechaConsumo'] is String) {
            try {
              fechaFormateada = formato.format(
                DateTime.parse(pedido['FechaConsumo']).toLocal()
              );
            } catch (e) {
              fechaFormateada = pedido['FechaConsumo'];
            }
          }
        }

        if (pedido['FechaConfirmado'] != null) {
          if (pedido['FechaConfirmado'] is String) {
            try {
              fechaConfirmadaFormateada = formato.format(
                DateTime.parse(pedido['FechaConfirmado']).toLocal()
              );
            } catch (e) {
              fechaConfirmadaFormateada = pedido['FechaConfirmado'];
            }
          }
        }

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
                              TextSpan(text: pedido['Nombre']),
                            ],                       
                          ),
                          style: const TextStyle(fontSize: 14),
                          softWrap: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.verified_user, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Tooltip(
                        message: 'Consumido por: ${pedido['ConsumidoPor']}',
                        child: Text(
                          'Consumido por: ${pedido['ConsumidoPor']}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
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
                    _buildDetalleFila('Fecha de Consumo:', fechaFormateada),
                    const SizedBox(height: 8),
                    _buildDetalleFila('Confirmado por:', pedido['ConfirmadoPor'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetalleFila('Fecha de Confirmación:', fechaConfirmadaFormateada),
                    const SizedBox(height: 8),  
                    _buildDetalleFila('Banco:', pedido['Banco'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetalleFila('N° Aprobación:', pedido['NumeroAprobacion'] ?? 'N/A'),
                    const SizedBox(height: 12),
                    // Imagen confirmada (si existe)
                    if (pedido['imagenUrl'] != null && (pedido['imagenUrl'] as String).isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              child: InteractiveViewer(
                                child: Image.network(
                                  pedido['imagenUrl'] as String,
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
                                  Text('Pulsa la miniatura para ver en grande', style: TextStyle(color: Colors.grey[700])),
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
  }

  Future<List<Map<String, dynamic>>> _loadConsumidosREST() async {
    try {
      const projectId = "tickets-firebase-aba0a";
      final url = Uri.parse(
        "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery",
      );

      final queryBody = {
        "structuredQuery": {
          "from": [{"collectionId": "Ilumel-Pedidos"}],
          "where": {
            "fieldFilter": {
              "field": {"fieldPath": "Estado"},
              "op": "EQUAL",
              "value": {"stringValue": "Consumido"}
            }
          }
        }
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(queryBody),
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        final pedidos = <Map<String, dynamic>>[];

        for (var result in results) {
          if (result['document'] != null) {
            final doc = result['document'];
            final fields = doc['fields'] as Map<String, dynamic>;

            pedidos.add({
              'N_Pedido': fields['N_Pedido']?['stringValue'] ?? 'N/A',
              'Nombre': fields['Nombre']?['stringValue'] ?? 'Sin nombre',
              'imagenUrl': fields['imagenUrl']?['stringValue'] ?? '',
              'ConsumidoPor': fields['ConsumidoPor']?['stringValue'] ?? 'Desconocido',
              'FechaConsumo': fields['FechaConsumo']?['timestampValue'],
              'FechaConfirmado': fields['FechaConfirmado']?['timestampValue'],
              'ConfirmadoPor': fields['ConfirmadoPor']?['stringValue'] ?? 'N/A',
              'Banco': fields['Banco']?['stringValue'] ?? 'N/A',
              'NumeroAprobacion': fields['NumeroAprobacion']?['stringValue'] ?? 'N/A',
            });
          }
        }

        // Ordenar por FechaConsumo descendente
        pedidos.sort((a, b) {
          final fechaA = a['FechaConsumo'];
          final fechaB = b['FechaConsumo'];

          if (fechaA == null && fechaB == null) return 0;
          if (fechaA == null) return 1;
          if (fechaB == null) return -1;

          try {
            DateTime dateA = DateTime.parse(fechaA.toString());
            DateTime dateB = DateTime.parse(fechaB.toString());
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        });

        return pedidos;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al cargar consumidos: $e');
    }
  }

  Widget _buildDetalleFila(String titulo, dynamic valor) {
    final String texto = valor?.toString() ?? 'N/A';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(color: Colors.black87),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}
