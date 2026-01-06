import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';

final FirebaseStorage storage = FirebaseStorage.instance;

/// Sube una imagen y devuelve la URL (funciona en web/móvil con plugin Firebase Storage)
Future<String?> uploadImage({
  File? file,
  Uint8List? bytes,
  String? name,
  String? docId,
}) async {
  final String fileName = docId != null
      ? "$docId.jpg"
      : name ?? DateTime.now().millisecondsSinceEpoch.toString();

  // 🔹 Tipo MIME según la extensión
  const String contentType = "image/jpeg";

  // 🌐 Caso Web/Móvil → usar plugin oficial
  Reference ref = storage.ref().child("images/$fileName");
  final metadata = SettableMetadata(contentType: contentType);

  UploadTask uploadTask;
  if (kIsWeb) {
    if (bytes == null) return null;
    uploadTask = ref.putData(bytes, metadata);
  } else {
    if (file == null) return null;
    uploadTask = ref.putFile(file, metadata);
  }

  final TaskSnapshot snapshot = await uploadTask;
  if (snapshot.state == TaskState.success) {
    return await ref.getDownloadURL();
  }
  return null;
}

