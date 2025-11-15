import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Cajera extends StatefulWidget {
  const Cajera({super.key});

  @override
  State<Cajera> createState() => _CajeraState();
}

class _CajeraState extends State<Cajera> {
  String? pedidoSeleccionado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transacciones Confirmadas"),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
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

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: pedidoSeleccionado == null
                          ? null
                          : () async {
                              await FirebaseFirestore.instance
                                  .collection('Ilumel-Pedidos')
                                  .doc(pedidoSeleccionado)
                                  .update({
                                'Estado': 'Consumido',
                                'FechaConsumo': DateTime.now(),
                              });

                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text("Pedido marcado como consumido."),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
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
              ),
            ],
          );
        },
      ),
    );
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
