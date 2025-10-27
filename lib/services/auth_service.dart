import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {

  Future<Map<String, dynamic>?> login(String codigo, String password) async {
    final doc = await FirebaseFirestore.instance.collection('Usuarios').doc(codigo).get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    if (data['Password'] == password) {
      return data;
    } else {
      return null;
    }
  }
}
