import 'package:flutter/material.dart';

class Imagen with ChangeNotifier {
  // Aquí manejarás la lógica para las imágenes, como su URL, etc.
  String? _imagenUrl;

  String? get imagenUrl => _imagenUrl;

  void setImagenUrl(String url) {
    _imagenUrl = url;
    notifyListeners();
  }
}
