import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mon_coloc/models/user_model.dart';

/// Service gérant les opérations Firestore pour la collection 'users'
/// et le téléversement de fichiers vers Firebase Storage.
class UserService {
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Sauvegarde ou met à jour un utilisateur dans Firestore.
  Future<void> sauvegarderUtilisateur(UserModel user) async {
    await _usersCollection.doc(user.uid).set(user.toFirestore());
  }

  /// Met à jour partiellement un utilisateur dans Firestore.
  Future<void> mettreAJourPartiel({
    required String uid,
    required Map<String, dynamic> donnees,
  }) async {
    await _usersCollection.doc(uid).update(donnees);
  }

  /// Récupère un utilisateur par son UID.
  Future<UserModel?> recupererUtilisateur(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Écoute en temps réel les changements d'un utilisateur.
  Stream<UserModel?> ecouterUtilisateur(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  /// Téléverse une image de profil vers Firebase Storage.
  /// Retourne l'URL de téléchargement.
  Future<String> televerserPhotoProfil({
    required String uid,
    required String cheminFichier,
  }) async {
    final ref = _storage.ref().child('photos_profil/$uid.jpg');
    final uploadTask = ref.putFile(File(cheminFichier));
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Téléverse un document justificatif vers Firebase Storage.
  /// Retourne l'URL de téléchargement.
  Future<String> televerserJustificatif({
    required String uid,
    required String cheminFichier,
  }) async {
    final ref = _storage.ref().child('justificatifs/${uid}_doc.jpg');
    final uploadTask = ref.putFile(File(cheminFichier));
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Téléverse des données d'image (bytes) pour la photo de profil (Flutter Web).
  Future<String> televerserPhotoProfilBytes({
    required String uid,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref().child('photos_profil/$uid.jpg');
    final uploadTask = ref.putData(bytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Téléverse des données d'image (bytes) pour un justificatif (Flutter Web).
  Future<String> televerserJustificatifBytes({
    required String uid,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref().child('justificatifs/${uid}_doc.jpg');
    final uploadTask = ref.putData(bytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}