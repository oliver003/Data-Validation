import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Sube una imagen vía REST API y devuelve la URL (Windows)
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

  // 💻 Caso Windows → usar REST API
  if (file == null && bytes == null) return null;

  final bucket = "tickets-firebase-aba0a.firebasestorage.app"; // ⚠️ cambia por tu bucket de Firebase Storage
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
