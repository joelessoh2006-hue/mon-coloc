import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mon_coloc/models/user_model.dart';

/// Service gérant les opérations Firestore pour la collection 'users'.
class UserService {
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  /// Sauvegarde ou met à jour un utilisateur dans Firestore.
  Future<void> sauvegarderUtilisateur(UserModel user) async {
    await _usersCollection.doc(user.uid).set(user.toFirestore());
  }

  /// Récupère un utilisateur par son UID.
  Future<UserModel?> recupererUtilisateur(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }
}