import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:divida_aqui/core/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Cria o usuário no Firebase Auth e salva o perfil no Firestore com role 1.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String birthDate,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = UserModel(
      uid: credential.user!.uid,
      name: name,
      email: email,
      birthDate: birthDate,
      role: 1,
    );

    await _db.collection('users').doc(user.uid).set(user.toMap());

    return credential;
  }

  /// Busca o perfil do usuário atual no Firestore.
  Future<UserModel?> fetchCurrentUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Atualiza nome e data de nascimento do usuário no Firestore.
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String birthDate,
  }) async {
    await _db.collection('users').doc(uid).update({
      'name': name,
      'birthDate': birthDate,
    });
  }

  /// Busca todos os usuários (apenas para admin role 0).
  Future<List<UserModel>> fetchAllUsers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
  }

  Future<void> signOut() => _auth.signOut();

  User? get currentUser => _auth.currentUser;
}
