import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class PickedImage {
  final XFile? xfile; // para móvil
  final Uint8List? bytes; // para web
  final String? name;

  PickedImage({this.xfile, this.bytes, this.name});
}

Future<PickedImage?> getImage() async {
  // Límite máximo de 10 MB
  const int kMaxImageBytes = 10 * 1024 * 1024;

  // 🌐 En Web usamos FilePicker
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true, // asegura que tengamos los bytes para verificar tamaño
  );

  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    // Verificar tamaño por metadata y por bytes si están disponibles
    final int size = file.size;
    if (size > kMaxImageBytes) {
      return null; // excede límite
    }

    final fileBytes = file.bytes;
    final fileName = file.name;

    return PickedImage(bytes: fileBytes, name: fileName);
  }
  return null;
}