import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/select_image.dart';
import 'package:flutter_application_2/services/upload_image.dart';

class Cliente extends StatefulWidget {
  const Cliente({super.key});

  @override
  State<Cliente> createState() => _ClienteState();
}

class _ClienteState extends State<Cliente> {

  // ignore: non_constant_identifier_names
  File? imagen_to_upload;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
      ),
      body: Column(
        children: [
          imagen_to_upload != null ? Image.file(imagen_to_upload!) : Container(
            margin: EdgeInsets.all(10),
            height: 200,
            width: double.infinity,
            color: Colors.blue,
          ),
          ElevatedButton(onPressed: () async {
            final imagen = await getImage();

            setState(() {
              if(imagen != null){
                imagen_to_upload = File(imagen.path);
              }
            });
          }, child: const Text("Seleccionar imagen")),

          ElevatedButton(onPressed: () async {
            if (imagen_to_upload == null) {
              return;
            }
            
            final uploaded = await uploadImage(imagen_to_upload!);
          }, child: const Text("Subir a Base de Datos"))
        ],
      )
    );
  }
}