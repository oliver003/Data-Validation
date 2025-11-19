import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class PickedImage {
  final XFile? xfile; // para móvil
  final Uint8List? bytes; // para web
  final String? name;

  PickedImage({this.xfile, this.bytes, this.name});
}

Future<PickedImage?> getImage() async {

  if (kIsWeb) {
    // 🌐 En Web usamos FilePicker
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      final fileName = result.files.first.name;

      return PickedImage(bytes: fileBytes, name: fileName);
    }
  } else {
    // 📱 En Móvil usamos ImagePicker
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      return PickedImage(xfile: image, name: image.name);
    }
  }
  return null;
}