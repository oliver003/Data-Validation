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

  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true, // intentamos traer bytes para verificar tamaño
  );

  if (result == null || result.files.isEmpty) return null;

  final file = result.files.first;

  // Verificar tamaño por metadata
  if (file.size > kMaxImageBytes) return null;

  // Para web usamos los bytes; para móvil tomamos la ruta en disco
  final Uint8List? fileBytes = file.bytes;
  final String? filePath = file.path;

  // Si tenemos bytes, los devolvemos (web). Si tenemos path, creamos un XFile (móvil)
  final XFile? xFile = filePath != null ? XFile(filePath, name: file.name) : null;

  return PickedImage(
    xfile: xFile,
    bytes: fileBytes,
    name: file.name,
  );
}