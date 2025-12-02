import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/main.dart' show AppData;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

String name = AppData.nombre;

class Contable extends StatefulWidget {
  const Contable({super.key});

  @override
  State<Contable> createState() => _ContableState();
}

class _ContableState extends State<Contable> {
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
              "value": {"stringValue": "Enviado"}
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
              'Nombre': fields['Nombre']?['stringValue'] ?? 'Sin nombre',
              'N_Pedido': fields['N_Pedido']?['stringValue'] ?? 'N/A',
              'imagenUrl': fields['imagenUrl']?['stringValue'] ?? '',
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
        title: const Text('Revisión de Facturas'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors:[
              Color.fromRGBO(134, 207, 61, 1), 
              Colors.white,                  
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter)
          ),
          width: double.infinity,
          height: kToolbarHeight * 4,
        ),
      ),
      body: (!kIsWeb && Platform.isWindows)
          ? _buildWindowsView()
          : _buildMobileWebView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarHistorialConfirmados,
        backgroundColor: const Color.fromRGBO(134, 207, 61, 1),
        icon: const Icon(Icons.history, color: Colors.white),
        label: const Text(
          'Historial',
          style: TextStyle(color: Colors.white),
        ),
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
      return const Center(child: Text('No hay facturas pendientes.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pedidos.length,
      itemBuilder: (context, index) => _buildPedidoCard(
        context,
        _pedidos[index]['id'],
        _pedidos[index]['Nombre'],
        _pedidos[index]['N_Pedido'],
        _pedidos[index]['imagenUrl'],
      ),
    );
  }

  Widget _buildMobileWebView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Ilumel-Pedidos')
          .where('Estado', isEqualTo: 'Enviado')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar los datos.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay facturas pendientes.'));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildPedidoCard(
              context,
              docs[index].id,
              data['Nombre'] ?? 'Sin nombre',
              data['N_Pedido'] ?? 'N/A',
              data['imagenUrl'] ?? '',
            );
          },
        );
      },
    );
  }

  Widget _buildPedidoCard(
    BuildContext context,
    String docId,
    String nombre,
    String pedido,
    String imagenUrl,
  ) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        title: Text('Pedido: #$pedido'),
        subtitle: nombre != 'Sin nombre' ? Text('Usuario: $nombre') : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagenUrl.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.image, color: Colors.blue),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: InteractiveViewer(
                        child: Image.network(imagenUrl),
                      ),
                    ),
                  );
                },
              )
            else
              const Icon(Icons.image_not_supported, color: Colors.grey),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _showConfirmDialog(context, docId, pedido),
            ),
          ],
        ),
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
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
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
                      Text(
                        'Pedidos Confirmados',
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
                
                // LISTA DE PEDIDOS CONFIRMADOS
                Expanded(
                  child: (!kIsWeb && Platform.isWindows)
                      ? _buildHistorialWindows()
                      : _buildHistorialMobileWeb(),
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
    );
  }

  Widget _buildHistorialWindows() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadConfirmadosREST(),
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
                  'No hay pedidos confirmados',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final pedidos = snapshot.data!;
        return _buildListaConfirmados(pedidos);
      },
    );
  }

  Widget _buildHistorialMobileWeb() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Ilumel-Pedidos')
          .where('Estado', isEqualTo: 'Confirmado')
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
                  'No hay pedidos confirmados',
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
            'ConfirmadoPor': data['ConfirmadoPor'] ?? 'Desconocido',
            'FechaConfirmado': data['FechaConfirmado'],
            'Banco': data['Banco'] ?? 'N/A',
            'NumeroAprobacion': data['NumeroAprobacion'] ?? 'N/A',
          };
        }).toList();

        // Ordenar manualmente por fecha (más reciente primero)
        pedidos.sort((a, b) {
          final fechaA = a['FechaConfirmado'];
          final fechaB = b['FechaConfirmado'];
          
          if (fechaA == null && fechaB == null) return 0;
          if (fechaA == null) return 1;
          if (fechaB == null) return -1;
          
          DateTime dateA = fechaA is Timestamp 
              ? fechaA.toDate() 
              : DateTime.parse(fechaA.toString());
          DateTime dateB = fechaB is Timestamp 
              ? fechaB.toDate() 
              : DateTime.parse(fechaB.toString());
          
          return dateB.compareTo(dateA); // Descendente
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
        if (pedido['FechaConfirmado'] != null) {
          if (pedido['FechaConfirmado'] is Timestamp) {
            fechaFormateada = formato.format(
              (pedido['FechaConfirmado'] as Timestamp).toDate()
            );
          } else if (pedido['FechaConfirmado'] is String) {
            try {
              fechaFormateada = formato.format(
                DateTime.parse(pedido['FechaConfirmado'])
              );
            } catch (e) {
              fechaFormateada = pedido['FechaConfirmado'];
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
            title: Text(
              'Pedido #${pedido['N_Pedido']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
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
                    Text(
                      'Cliente: ${pedido['Nombre']}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.verified_user, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Confirmado por: ${pedido['ConfirmadoPor']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
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
                    _buildDetalleFila('Fecha de Confirmación', fechaFormateada),
                    const SizedBox(height: 8),
                    _buildDetalleFila('Banco', pedido['Banco'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetalleFila('N° Aprobación', pedido['NumeroAprobacion'] ?? 'N/A'),
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
          width: 150,
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

  Future<List<Map<String, dynamic>>> _loadConfirmadosREST() async {
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
              'N_Pedido': fields['N_Pedido']?['stringValue'] ?? 'N/A',
              'Nombre': fields['Nombre']?['stringValue'] ?? 'Sin nombre',
              'ConfirmadoPor': fields['ConfirmadoPor']?['stringValue'] ?? 'Desconocido',
              'FechaConfirmado': fields['FechaConfirmado']?['timestampValue'],
              'Banco': fields['Banco']?['stringValue'] ?? 'N/A',
              'NumeroAprobacion': fields['NumeroAprobacion']?['stringValue'] ?? 'N/A',
            });
          }
        }

        // Ordenar manualmente por fecha (más reciente primero)
        pedidos.sort((a, b) {
          final fechaA = a['FechaConfirmado'];
          final fechaB = b['FechaConfirmado'];
          
          if (fechaA == null && fechaB == null) return 0;
          if (fechaA == null) return 1;
          if (fechaB == null) return -1;
          
          try {
            DateTime dateA = DateTime.parse(fechaA.toString());
            DateTime dateB = DateTime.parse(fechaB.toString());
            return dateB.compareTo(dateA); // Descendente
          } catch (e) {
            return 0;
          }
        });

        return pedidos;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al cargar confirmados: $e');
    }
  }

  void _showConfirmDialog(BuildContext context, String docId, String pedido) {
    final aprobacionController = TextEditingController();
    String bancoSeleccionado = "Popular";
    String bancoPersonalizado = "";

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirmar Factura'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Deseas confirmar el pedido #$pedido?',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: bancoSeleccionado,
                    decoration: InputDecoration(
                      labelText: "Banco",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: "Popular", child: Text("Popular")),
                      DropdownMenuItem(value: "BanReservas", child: Text("Reservas")),
                      DropdownMenuItem(value: "BHD", child: Text("BHD")),
                      DropdownMenuItem(value: "Scotiabank", child: Text("Scotiabank")),
                      DropdownMenuItem(value: "Vimenca", child: Text("Vimenca")),
                      DropdownMenuItem(value: "Otro", child: Text("Otro...")),
                    ],
                    onChanged: (valor) {
                      setState(() {
                        bancoSeleccionado = valor!;
                      });
                    },
                  ),
                  if (bancoSeleccionado == "Otro") ...[
                    const SizedBox(height: 15),
                    TextField(
                      onChanged: (value) {
                        bancoPersonalizado = value.trim();
                      },
                      decoration: InputDecoration(
                        labelText: "Especificar Banco",
                        hintText: "Ej: BanReservas",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.account_balance),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    controller: aprobacionController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Número de aprobación',
                      hintText: 'Ej: 849392',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.confirmation_number),
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actionsPadding: const EdgeInsets.only(bottom: 10),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final numeroAprobacion = aprobacionController.text.trim();

                    if (numeroAprobacion.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor ingresa el número de aprobación'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    if (bancoSeleccionado == "Otro" && bancoPersonalizado.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Debes escribir el nombre del banco'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final bancoFinal = bancoSeleccionado == "Otro"
                        ? bancoPersonalizado
                        : bancoSeleccionado;

                    Navigator.of(dialogContext).pop();

                    await _confirmarPedido(context, docId, pedido, bancoFinal, numeroAprobacion);
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarPedido(
    BuildContext context,
    String docId,
    String pedido,
    String banco,
    String numeroAprobacion,
  ) async {
    try {
      if (kIsWeb || !Platform.isWindows) {
        await FirebaseFirestore.instance
            .collection('Ilumel-Pedidos')
            .doc(docId)
            .update({
          'ConfirmadoPor': name,
          'Estado': 'Confirmado',
          'FechaConfirmado': DateTime.now(),
          'Banco': banco,
          'NumeroAprobacion': numeroAprobacion,
        });
      } else {
        const projectId = "tickets-firebase-aba0a";
        final firestoreUrl = Uri.parse(
          "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/Ilumel-Pedidos/$docId?updateMask.fieldPaths=ConfirmadoPor&updateMask.fieldPaths=Estado&updateMask.fieldPaths=FechaConfirmado&updateMask.fieldPaths=Banco&updateMask.fieldPaths=NumeroAprobacion",
        );

        final updateBody = {
          "fields": {
            "ConfirmadoPor": {"stringValue": name},
            "Estado": {"stringValue": "Confirmado"},
            "FechaConfirmado": {
              "timestampValue": DateTime.now().toUtc().toIso8601String()
            },
            "Banco": {"stringValue": banco},
            "NumeroAprobacion": {"stringValue": numeroAprobacion},
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Pedido #$pedido confirmado correctamente.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al confirmar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}