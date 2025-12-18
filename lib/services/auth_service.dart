import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  Future<Map<String, dynamic>?> login(String codigo, String password) async {
    // 🌐 Si estamos en Android/iOS/Web, usar el plugin oficial Firestore
    final doc = await FirebaseFirestore.instance
        .collection('Usuarios')
        .doc(codigo)
        .get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    return data['Password'] == password ? data : null;
  }
}
