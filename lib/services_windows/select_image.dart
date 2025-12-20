import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class PickedImage {
  final XFile? xfile; // para Windows/móvil
  final Uint8List? bytes; // para web
  final String? name;

  PickedImage({this.xfile, this.bytes, this.name});
}

Future<PickedImage?> getImage() async {
  // Límite máximo de 10 MB
  const int kMaxImageBytes = 10 * 1024 * 1024;

  // 💻 En Windows usamos ImagePicker (igual que móvil)
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  if (image != null) {
    // Verificar tamaño del archivo seleccionado
    final int fileSize = await image.length();
    if (fileSize > kMaxImageBytes) {
      return null; // excede límite
    }
    return PickedImage(xfile: image, name: image.name);
  }
  return null;
}
