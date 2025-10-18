import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

final FirebaseStorage storage = FirebaseStorage.instance;

/// Sube una imagen a Firebase Storage y devuelve la URL de descarga.
/// [image] → archivo a subir.
/// [docId] → opcional, se usa para nombrar la imagen igual que el documento Firestore.
Future<String?> uploadImage(File image, {String? docId}) async {

  // Si se pasa un docId, usa ese nombre para vincular con Firestore
  final String nombreArchivo = docId != null
      ? "$docId.jpg"
      : image.path.split("/").last;

  // Carpeta de destino en Firebase Storage
  Reference ubicacionArchivo = storage.ref().child("images").child(nombreArchivo);

  // Subir imagen
  final UploadTask subiendoImagen = ubicacionArchivo.putFile(image);
  final TaskSnapshot snapshot = await subiendoImagen.whenComplete(() => true);

  // Verificar estado y devolver URL pública
  if (snapshot.state == TaskState.success) {
     final String url = await ubicacionArchivo.getDownloadURL();
    return url; // 🔹 devolvemos la URL
  } else {
     return null;
  }
} 
