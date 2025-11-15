import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/main.dart' show AppData;

String name = AppData.nombre;

class Contable extends StatelessWidget {
  const Contable({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión de Facturas'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
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
              final docId = docs[index].id;
              final nombre = data['Nombre'] ?? 'Sin nombre';
              final pedido = data['N_Pedido'] ?? 'N/A';
              final imagenUrl = data['imagenUrl'] ?? '';

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: ListTile(
                  title: Text('Pedido: #$pedido'),
                  subtitle: nombre != 'Sin nombre' ? Text('Usuario: $nombre') : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [if (imagenUrl.isNotEmpty)
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
                        onPressed: () {
                          final aprobacionController = TextEditingController();
                          
                          String bancoSeleccionado = "Popular"; // valor inicial del dropdown
                          String bancoPersonalizado = ""; // cuando se elige "Otro"

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

                                        // ---------- MENÚ DESPLEGABLE DE BANCOS ----------
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
                                            DropdownMenuItem(value: "Reservas", child: Text("Reservas")),
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

                                        // ---------- SI ELIGE OTRO, MOSTRAR CAJA DE TEXTO ----------
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

                                        // ---------- NÚMERO DE APROBACIÓN ----------
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
                                      // ---------- BOTÓN CANCELAR ----------
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

                                      // ---------- BOTÓN CONFIRMAR ----------
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

                                          try {
                                            await FirebaseFirestore.instance
                                                .collection('Ilumel-Pedidos')
                                                .doc(docId)
                                                .update({
                                              'ConfirmadoPor': name,
                                              'Estado': 'Confirmado',
                                              'FechaConfirmado': DateTime.now(),
                                              'Banco': bancoFinal,
                                              'NumeroAprobacion': numeroAprobacion,
                                            });

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
                                        },
                                        child: const Text('Confirmar'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
