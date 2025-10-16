import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

final FirebaseStorage storage = FirebaseStorage.instance;

Future<bool> uploadImage(File image) async {

  // print(image.path);
  final String nombreArchivo = image.path.split("/").last;

  Reference ubicacionArchivo = storage.ref().child("images").child(nombreArchivo);

  final UploadTask subiendoImagen = ubicacionArchivo.putFile(image);
  // print(subiendoImagen);

  final TaskSnapshot snapshot = await subiendoImagen.whenComplete( () => true);
  // print(snapshot);

  final String url = await snapshot.ref.getDownloadURL();
  // print(url);
  
  return false;
}