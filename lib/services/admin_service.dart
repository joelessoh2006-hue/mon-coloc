import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mon_coloc/models/user_model.dart';

/// Service dédié aux opérations d'administration et de modération.
/// Permet de gérer les validations des logements et des comptes bailleurs.
class AdminService {
  final CollectionReference _logementsCollection =
      FirebaseFirestore.instance.collection('logements');
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  // ---------------------------------------------------------------------------
  // LOGEMENTS EN ATTENTE
  // ---------------------------------------------------------------------------

  /// Récupère en temps réel les logements dont le statut est 'en_attente'.
  Stream<QuerySnapshot> ecouterLogementsEnAttente() {
    return _logementsCollection
        .where('statut', isEqualTo: 'en_attente')
        .orderBy('datePublication', descending: true)
        .snapshots();
  }

  /// Récupère une fois les logements en attente (pour chargement initial).
  Future<QuerySnapshot> recupererLogementsEnAttente() async {
    return await _logementsCollection
        .where('statut', isEqualTo: 'en_attente')
        .orderBy('datePublication', descending: true)
        .get();
  }

  // ---------------------------------------------------------------------------
  // BAILLEURS EN ATTENTE
  // ---------------------------------------------------------------------------

  /// Récupère en temps réel les comptes bailleurs ayant status == 'en_attente'.
  Stream<QuerySnapshot> ecouterBailleursEnAttente() {
    return _usersCollection
        .where('role', isEqualTo: 'bailleur')
        .where('status', isEqualTo: 'en_attente')
        .snapshots();
  }

  /// Récupère une fois les bailleurs en attente.
  Future<QuerySnapshot> recupererBailleursEnAttente() async {
    return await _usersCollection
        .where('role', isEqualTo: 'bailleur')
        .where('status', isEqualTo: 'en_attente')
        .get();
  }

  // ---------------------------------------------------------------------------
  // ACTIONS DE MODÉRATION
  // ---------------------------------------------------------------------------

  /// Approuve un logement en mettant son statut à 'valide'.
  Future<void> approuverLogement(String logementId) async {
    await _logementsCollection.doc(logementId).update({
      'statut': 'valide',
      'dateValidation': FieldValue.serverTimestamp(),
    });
  }

  /// Rejette un logement en mettant son statut à 'rejete'.
  Future<void> rejeterLogement(String logementId) async {
    await _logementsCollection.doc(logementId).update({
      'statut': 'rejete',
      'dateRejet': FieldValue.serverTimestamp(),
    });
  }

  /// Approuve un compte bailleur en mettant son status à 'valide'
  /// et en activant la vérification.
  Future<void> approuverBailleur(String bailleurUid) async {
    await _usersCollection.doc(bailleurUid).update({
      'status': 'valide',
      'estVerifie': true,
      'dateValidation': FieldValue.serverTimestamp(),
    });
  }

  /// Rejette un compte bailleur en mettant son status à 'rejete'.
  Future<void> rejeterBailleur(String bailleurUid) async {
    await _usersCollection.doc(bailleurUid).update({
      'status': 'rejete',
      'dateRejet': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // UTILITAIRES
  // ---------------------------------------------------------------------------

  /// Récupère les informations d'un bailleur à partir de son UID.
  Future<UserModel?> recupererBailleur(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Récupère les informations d'un logement à partir de son ID.
  Future<Map<String, dynamic>?> recupererLogement(String logementId) async {
    final doc = await _logementsCollection.doc(logementId).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>?;
  }
}