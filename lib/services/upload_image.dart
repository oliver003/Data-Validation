import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final FirebaseStorage storage = FirebaseStorage.instance;

/// Sube una imagen (desde móvil o web) y devuelve la URL
Future<String?> uploadImage({
  File? file,
  Uint8List? bytes,
  String? name,
  String? docId,
}) async {
  final String fileName = docId != null
      ? "$docId.jpg"
      : name ?? DateTime.now().millisecondsSinceEpoch.toString();

  Reference ref = storage.ref().child("images/$fileName");

  // 🔹 Tipo MIME según la extensión
  String contentType = "image/jpeg";
  final metadata = SettableMetadata(contentType: contentType);

  UploadTask uploadTask;

  if (kIsWeb) {
    // 🌐 Subida en Web con bytes
    if (bytes == null) return null;
    uploadTask = ref.putData(bytes, metadata);
  } else {
    // 📱 Subida en Móvil con File
    if (file == null) return null;
    uploadTask = ref.putFile(file);
  }

  final TaskSnapshot snapshot = await uploadTask;
  if (snapshot.state == TaskState.success) {
    final url = await ref.getDownloadURL();
    return url;
  }
  return null;
}
