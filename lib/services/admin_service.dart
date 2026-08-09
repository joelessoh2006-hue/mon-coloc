import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mon_coloc/models/user_model.dart';

/// Service dédié aux opérations d'administration et de modération.
/// Permet de gérer les validations des logements et des comptes utilisateurs,
/// la consultation des signalements et le blocage de comptes.
class AdminService {
  final CollectionReference _logementsCollection = FirebaseFirestore.instance
      .collection('logements');
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');
  final CollectionReference _reportsCollection = FirebaseFirestore.instance
      .collection('signalements');

  // ===========================================================================
  // LOGEMENTS EN ATTENTE
  // ===========================================================================

  /// Récupère en temps réel les logements dont le statut est 'en_attente'.
  /// Utilise l'index composé : status ASC, datePublication DESC.
  Stream<QuerySnapshot> ecouterLogementsEnAttente() {
    return _logementsCollection
        .where('status', isEqualTo: 'en_attente')
        .snapshots();
  }

  /// Récupère une fois les logements en attente (pour chargement initial).
  Future<QuerySnapshot> recupererLogementsEnAttente() async {
    return await _logementsCollection
        .where('status', isEqualTo: 'en_attente')
        .get();
  }

  /// Approuve un logement en mettant son statut à 'valide'.
  Future<void> approuverLogement(String logementId) async {
    await _logementsCollection.doc(logementId).update({
      'status': 'valide',
      'dateValidation': FieldValue.serverTimestamp(),
    });
  }

  /// Rejette un logement en mettant son statut à 'rejete'.
  Future<void> rejeterLogement(String logementId) async {
    await _logementsCollection.doc(logementId).update({
      'status': 'rejete',
      'dateRejet': FieldValue.serverTimestamp(),
    });
  }

  /// Récupère les données d'un logement par son ID.
  Future<Map<String, dynamic>?> recupererLogement(String logementId) async {
    final doc = await _logementsCollection.doc(logementId).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>?;
  }

  // ===========================================================================
  // BAILLEURS
  // ===========================================================================

  /// Récupère en temps réel les comptes bailleurs non vérifiés.
  Stream<QuerySnapshot> ecouterBailleursEnAttente() {
    return _usersCollection
        .where('role', isEqualTo: 'bailleur')
        .where('estVerifie', isEqualTo: false)
        .snapshots();
  }

  /// Récupère une fois les bailleurs non vérifiés.
  Future<QuerySnapshot> recupererBailleursEnAttente() async {
    return await _usersCollection
        .where('role', isEqualTo: 'bailleur')
        .where('estVerifie', isEqualTo: false)
        .get();
  }

  /// Récupère en temps réel TOUS les bailleurs (pour la gestion).
  /// Le tri est effectué côté client pour plus de flexibilité.
  Stream<QuerySnapshot> ecouterTousLesBailleurs() {
    return _usersCollection.where('role', isEqualTo: 'bailleur').snapshots();
  }

  /// Récupère en temps réel les comptes bailleurs non vérifiés ET non bloqués.
  Stream<QuerySnapshot> ecouterBailleursEnAttenteDeValidation() {
    return _usersCollection
        .where('role', isEqualTo: 'bailleur')
        .where('estVerifie', isEqualTo: false)
        .where('estBloque', isEqualTo: false)
        .snapshots();
  }

  /// Approuve un compte bailleur (status -> valide, estVerifie -> true).
  Future<void> approuverBailleur(String bailleurUid) async {
    await _usersCollection.doc(bailleurUid).update({
      'status': 'valide',
      'estVerifie': true,
      'dateValidation': FieldValue.serverTimestamp(),
    });
  }

  /// Rejette un compte bailleur.
  Future<void> rejeterBailleur(String bailleurUid) async {
    await _usersCollection.doc(bailleurUid).update({
      'status': 'rejete',
      'dateRejet': FieldValue.serverTimestamp(),
    });
  }

  /// Récupère les infos d'un bailleur (ou tout utilisateur) par son UID.
  Future<UserModel?> recupererUtilisateur(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // ===========================================================================
  // ÉTUDIANTS (vérification des documents)
  // ===========================================================================

  /// Récupère en temps réel les étudiants ayant un justificatif à vérifier.
  /// Filtre : role == 'etudiant' ET justificatifUrl existe ET estVerifie == false.
  Stream<QuerySnapshot> ecouterEtudiantsAVerifier() {
    return _usersCollection
        .where('role', isEqualTo: 'etudiant')
        .where('estVerifie', isEqualTo: false)
        .where('justificatifIdentiteUrl', isNotEqualTo: null)
        .snapshots();
  }

  /// Récupère une fois les étudiants à vérifier.
  Future<QuerySnapshot> recupererEtudiantsAVerifier() async {
    return await _usersCollection
        .where('role', isEqualTo: 'etudiant')
        .where('estVerifie', isEqualTo: false)
        .where('justificatifIdentiteUrl', isNotEqualTo: null)
        .get();
  }

  /// Récupère en temps réel les étudiants non vérifiés ET non bloqués.
  Stream<QuerySnapshot> ecouterEtudiantsEnAttenteDeValidation() {
    return _usersCollection
        .where('role', isEqualTo: 'etudiant')
        .where('estVerifie', isEqualTo: false)
        .where('estBloque', isEqualTo: false)
        .snapshots();
  }

  /// Récupère en temps réel TOUS les étudiants (pour la gestion).
  /// Le tri est effectué côté client pour plus de flexibilité.
  Stream<QuerySnapshot> ecouterTousLesEtudiants() {
    return _usersCollection.where('role', isEqualTo: 'etudiant').snapshots();
  }

  /// Récupère en temps réel les étudiants non bloqués.
  Stream<QuerySnapshot> ecouterEtudiantsNonBloques() {
    return _usersCollection
        .where('role', isEqualTo: 'etudiant')
        .where('estBloque', isEqualTo: false)
        .snapshots();
  }

  /// Marque un étudiant comme vérifié (estVerifie: true).
  Future<void> verifierEtudiant(String uid) async {
    await _usersCollection.doc(uid).update({
      'estVerifie': true,
      'dateVerification': FieldValue.serverTimestamp(),
    });
  }

  /// Retire la vérification d'un étudiant.
  Future<void> deverifierEtudiant(String uid) async {
    await _usersCollection.doc(uid).update({
      'estVerifie': false,
      'dateVerification': FieldValue.serverTimestamp(),
    });
  }

  // ===========================================================================
  // SIGNALEMENTS (reports)
  // ===========================================================================

  /// Récupère en temps réel la liste des signalements, du plus récent au plus ancien.
  Stream<QuerySnapshot> ecouterSignalements() {
    return _reportsCollection
        .orderBy('dateSignalement', descending: true)
        .snapshots();
  }

  /// Récupère une fois tous les signalements.
  Future<QuerySnapshot> recupererSignalements() async {
    return await _reportsCollection
        .orderBy('dateSignalement', descending: true)
        .get();
  }

  /// Supprime un signalement après traitement.
  Future<void> supprimerSignalement(String reportId) async {
    await _reportsCollection.doc(reportId).delete();
  }

  // ===========================================================================
  // BLOCAGE / DÉBLOCAGE DE COMPTES
  // ===========================================================================

  /// Bloque un bailleur et suspend tous ses logements de manière atomique.
  /// 1. Met à jour le document du bailleur dans `users` :
  ///    - `estBloque`: true
  ///    - `estVerifie`: false
  ///    - `status`: 'bloque'
  /// 2. Met à jour tous ses logements dans `logements` :
  ///    - `status`: 'suspendu'
  Future<void> bloquerCompte(String uid) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Mettre à jour le document de l'utilisateur
    final userRef = _usersCollection.doc(uid);
    batch.update(userRef, {
      'estBloque': true,
      'status': 'bloque',
      'dateBlocage': FieldValue.serverTimestamp(),
    });

    // 2. Suspendre tous les logements du bailleur
    final logementsQuery = await _logementsCollection
        .where('idBailleur', isEqualTo: uid)
        .get();

    for (final doc in logementsQuery.docs) {
      batch.update(doc.reference, {'status': 'suspendu'});
    }

    // Exécuter l'opération atomique
    await batch.commit();
  }

  /// Débloque un utilisateur en passant estBloque à false.
  Future<void> debloquerCompte(String uid) async {
    await _usersCollection.doc(uid).update({
      'estBloque': false,
      'status': 'valide',
      'dateBlocage': FieldValue.delete(),
    });
  }

  /// Récupère en temps réel tous les comptes (étudiants et bailleurs) bloqués.
  Stream<QuerySnapshot> ecouterComptesBloques() {
    return _usersCollection.where('estBloque', isEqualTo: true).snapshots();
  }

  /// Vérifie si un utilisateur est bloqué.
  Future<bool> estCompteBloque(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;
    return data['estBloque'] == true;
  }
}
