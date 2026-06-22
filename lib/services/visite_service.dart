import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mon_coloc/models/visite_model.dart';

/// Service gérant les demandes de visite (collection 'visites').
class VisiteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUid => _auth.currentUser?.uid;

  /// Crée une nouvelle demande de visite avec le statut 'en_attente'.
  Future<void> creerDemandeVisite({
    required String bailleurId,
    required String logementId,
    required String logementTitle,
    required DateTime dateVisite,
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('Utilisateur non connecté');

    // Récupérer le prénom/nom de l'étudiant
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final prenom = userDoc.data()?['prenom'] as String? ?? 'Étudiant';
    final nom = userDoc.data()?['nom'] as String? ?? '';
    final studentName = '$prenom $nom'.trim();

    final visiteRef = _firestore.collection('visites').doc();
    final visite = VisiteModel(
      id: visiteRef.id,
      studentId: uid,
      studentName: studentName,
      bailleurId: bailleurId,
      logementId: logementId,
      logementTitle: logementTitle,
      dateVisite: dateVisite,
      status: 'en_attente',
    );

    await visiteRef.set(visite.toFirestore());
  }

  /// Récupère les demandes de visite pour un bailleur (stream temps réel).
  Stream<QuerySnapshot> ecouterVisitesBailleur(String bailleurId) {
    return _firestore
        .collection('visites')
        .where('bailleurId', isEqualTo: bailleurId)
        .orderBy('creeLe', descending: true)
        .snapshots();
  }

  /// Récupère les demandes de visite pour un étudiant (stream temps réel).
  Stream<QuerySnapshot> ecouterVisitesEtudiant(String studentId) {
    return _firestore
        .collection('visites')
        .where('studentId', isEqualTo: studentId)
        .orderBy('creeLe', descending: true)
        .snapshots();
  }

  /// Met à jour le statut d'une demande de visite.
  Future<void> mettreAJourStatut({
    required String visiteId,
    required String nouveauStatut, // 'confirme' ou 'refuse'
  }) async {
    await _firestore.collection('visites').doc(visiteId).update({
      'status': nouveauStatut,
    });
  }

  /// Accepte une visite : met à jour le statut et envoie un message automatique
  /// dans la conversation chat entre le bailleur et l'étudiant.
  Future<void> accepterVisite({
    required String visiteId,
    required String studentId,
    required String logementTitle,
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('Utilisateur non connecté');

    // 1. Mettre à jour le statut de la visite
    await mettreAJourStatut(visiteId: visiteId, nouveauStatut: 'confirme');

    // 2. Récupérer ou créer une conversation entre le bailleur et l'étudiant
    final ids = [uid, studentId]..sort();
    final conversationId = '${ids[0]}_${ids[1]}';

    final docRef = _firestore.collection('conversations').doc(conversationId);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'membres': [uid, studentId],
        'dernierMessage': '',
        'misAJourLe': FieldValue.serverTimestamp(),
        'creeLe': FieldValue.serverTimestamp(),
      });
    }

    // 3. Envoyer un message automatique de confirmation
    final messageAuto =
        '✅ Bonjour, votre demande de visite pour "$logementTitle" a été acceptée ! '
        'Je vous attends à la date convenue. À bientôt !';

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
      'envoyePar': uid,
      'texte': messageAuto,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 4. Mettre à jour le dernier message et le nonLuPar
    await docRef.update({
      'dernierMessage': messageAuto,
      'misAJourLe': FieldValue.serverTimestamp(),
      'nonLuPar': [studentId],
    });
  }

  /// Refuse une visite : met juste à jour le statut.
  Future<void> refuserVisite(String visiteId) async {
    await mettreAJourStatut(visiteId: visiteId, nouveauStatut: 'refuse');
  }
}