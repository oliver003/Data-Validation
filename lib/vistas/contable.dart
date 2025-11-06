import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
            .where('estado', isEqualTo: 'Enviado')
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
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('Ilumel-Pedidos')
                              .doc(docId)
                              .update({'ConfirmadoPor': 'Contabilidad', 'estado':'Confirmado'});

                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Pedido #$pedido confirmado.')),
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
