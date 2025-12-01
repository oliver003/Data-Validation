import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';

final FirebaseStorage storage = FirebaseStorage.instance;

/// Sube una imagen y devuelve la URL (funciona en móvil/web con plugin y en Windows con REST)
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
  if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
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

  // 💻 Caso Windows → usar REST API
  else if (Platform.isWindows) {
    if (file == null && bytes == null) return null;

    final bucket = "gs://tickets-firebase-aba0a.firebasestorage.app"; // ⚠️ cambia por tu bucket de Firebase Storage
    final objectName = "images/$fileName";

    final url = Uri.parse(
      "https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=$objectName",
    );

    final response = await http.post(
      url,
      headers: {"Content-Type": contentType},
      body: file != null ? await file.readAsBytes() : bytes,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['mediaLink']; // URL pública del archivo
    } else {
      // ignore: avoid_print
      print("Error subiendo archivo: ${response.body}");
      return null;
    }
  }

  return null;
}

