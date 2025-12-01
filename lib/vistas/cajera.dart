import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_application_2/main.dart' show AppData;

final String nombre = AppData.nombre;

class Cajera extends StatefulWidget {
  const Cajera({super.key});

  @override
  State<Cajera> createState() => _CajeraState();
}

class _CajeraState extends State<Cajera> {
  String? pedidoSeleccionado;
  List<Map<String, dynamic>> _pedidos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isWindows) {
      _loadPedidosREST();
      Future.delayed(const Duration(seconds: 5), _startPolling);
    }
  }

  void _startPolling() {
    if (!mounted || kIsWeb || !Platform.isWindows) return;
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
            final docId = (doc['name'] as String).split('/').last;

            pedidos.add({
              'id': docId,
              'Nombre': fields['Nombre']?['stringValue'] ?? 'N/A',
              'N_Pedido': fields['N_Pedido']?['stringValue'] ?? 'N/A',
              'imagenUrl': fields['imagenUrl']?['stringValue'] ?? '',
              'ConfirmadoPor': fields['ConfirmadoPor']?['stringValue'],
              'Banco': fields['Banco']?['stringValue'],
              'NumeroAprobacion': fields['NumeroAprobacion']?['stringValue'],
              'Estado': fields['Estado']?['stringValue'],
              'Fecha': fields['Fecha']?['timestampValue'],
              'FechaConfirmado': fields['FechaConfirmado']?['timestampValue'],
              'FechaConsumido': fields['FechaConsumido']?['timestampValue'],
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
      body: (!kIsWeb && Platform.isWindows)
          ? _buildWindowsView()
          : _buildMobileWebView(),
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
              final docId = data['id'];
              final imagenUrl = data["imagenUrl"] ?? "";

              return ListTile(
                title: Text("Pedido #${data['N_Pedido'] ?? 'N/A'}"),
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
              );
            },
          ),
        ),
        _buildActionButtons(),
      ],
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

                    return ListTile(
                      title: Text("Pedido #${data['N_Pedido'] ?? 'N/A'}"),
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
                          // ==== ICONO DE IMAGEN ====
                          if (imagenUrl.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.image, color: Colors.blue),
                              onPressed: () {
                                mostrarImagen(context, imagenUrl);
                              },
                            ),

                          // ==== MENÚ DE OPCIONES ====
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 123, 243, 79),
              foregroundColor: Colors.white,
            ),
            onPressed: pedidoSeleccionado == null ? null : _showConsumirConfirmDialog,
            child: const Text("Consumir"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: pedidoSeleccionado == null
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Función de impresión aquí."),
                      ),
                    );
                  },
            child: const Text("Imprimir"),
          ),
        ],
      ),
    );
  }

  void _showConsumirConfirmDialog() {
    if (pedidoSeleccionado == null) return;
    String pedidoNumero = pedidoSeleccionado!;
    // Intentar obtener el número de pedido real si estamos en Windows (REST)
    if (!kIsWeb && Platform.isWindows) {
      final match = _pedidos.firstWhere(
        (p) => p['id'] == pedidoSeleccionado,
        orElse: () => {},
      );
      pedidoNumero = match['N_Pedido'] ?? pedidoNumero;
        }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Consumo'),
        content: Text('¿Deseas marcar el pedido $pedidoNumero como consumido? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _consumirPedido();
            },
            child: const Text('Consumir'),
          ),
        ],
      ),
    );
  }

  Future<void> _consumirPedido() async {
    if (pedidoSeleccionado == null) return;

    try {
      if (kIsWeb || !Platform.isWindows) {
        await FirebaseFirestore.instance
            .collection('Ilumel-Pedidos')
            .doc(pedidoSeleccionado)
            .update({
          'Estado': 'Consumido',
          'FechaConsumo': DateTime.now(),
          'ConsumidoPor': nombre,
        });
      } else {
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
        }
      }

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

  // ==================== MOSTRAR DATOS ====================
  void mostrarDatosPedido(BuildContext context, Map<String, dynamic> data) {
    final DateFormat formato = DateFormat("dd/MM/yyyy hh:mm a");

    // --- FUNCIÓN PARA FORMATEAR FECHAS ---
    String formatear(dynamic valor) {
      if (valor is Timestamp) {
        return formato.format(valor.toDate());
      }
      return valor?.toString() ?? "";
    }

    // Quitar imagenURL
    final Map<String, dynamic> datos = Map.of(data);
    datos.remove("imagenUrl");

    // --- REEMPLAZAR TODAS LAS FECHAS ---
    datos["Fecha"] = formatear(datos["Fecha"]);
    datos["FechaConfirmado"] = formatear(datos["FechaConfirmado"]);
    datos["FechaConsumido"] = formatear(datos["FechaConsumido"]);

    // --- ORDEN QUE QUIERES ---
    final List<String> orden = [
      "N_Pedido",
      "Nombre",
      "Fecha",
      "ConfirmadoPor",
      "FechaConfirmado",
      "ConsumidoPor",
      "FechaConsumido",
      "Banco",
      "NumeroAprobacion",
      "Estado",
    ];

    // Diccionario con nombres bonitos
    final Map<String, String> nombresBonitos = {
      "N_Pedido": "Número de Pedido",
      "Nombre": "Cliente",
      "Fecha": "Fecha del Pedido",
      "ConfirmadoPor": "Confirmado por",
      "FechaConfirmado": "Fecha de Confirmación",
      "ConsumidoPor": "Consumido por",
      "FechaConsumido": "Fecha de Consumo",
      "Banco": "Banco",
      "NumeroAprobacion": "Número de Aprobación",
      "Estado": "Estado",
    };

    // Ordenar datos
    final Map<String, dynamic> datosOrdenados = {};

    for (var campo in orden) {
      if (datos.containsKey(campo)) {
        datosOrdenados[campo] = datos[campo];
        datos.remove(campo);
      }
    }

    datosOrdenados.addAll(datos);

    // --- FILTRAR CAMPOS VACÍOS O NULOS ---
    final camposFiltrados = datosOrdenados.entries.where((entry) {
      final valor = entry.value;

      if (valor == null) return false;
      if (valor.toString().trim().isEmpty) return false;
      if (valor.toString().trim().toLowerCase() == "null") return false;

      return true;
    }).toList();

    // --- MOSTRAR DIÁLOGO ---
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
                final value = entry.value;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    "$key: $value",
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Cerrar"),
            )
          ],
        );
      },
    );
  }


  // ==================== MOSTRAR IMAGEN ====================
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
}
