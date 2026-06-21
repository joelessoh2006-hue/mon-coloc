import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:mon_coloc/models/equipe_model.dart';

/// Service gérant les équipes de colocation (collection 'equipes').
///
/// Permet de :
/// - Créer une nouvelle équipe avec 2 membres
/// - Ajouter un membre à une équipe existante
/// - Récupérer les infos d'une équipe
/// - Récupérer l'équipe d'un utilisateur
class EquipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUid => _auth.currentUser?.uid;

  /// Récupère l'équipe d'un utilisateur à partir de son idEquipe.
  Future<EquipeModel?> recupererEquipe(String equipeId) async {
    try {
      final doc = await _firestore.collection('equipes').doc(equipeId).get();
      if (!doc.exists) return null;
      return EquipeModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Erreur recupererEquipe: $e');
      return null;
    }
  }

  /// Récupère l'équipe de l'utilisateur connecté.
  /// Nécessite que l'utilisateur ait un champ `idEquipe` dans son profil.
  Future<EquipeModel?> recupererEquipeCourante() async {
    final uid = _currentUid;
    if (uid == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;

      final equipeId = userDoc.data()?['idEquipe'] as String?;
      if (equipeId == null || equipeId.isEmpty) return null;

      return recupererEquipe(equipeId);
    } catch (e) {
      debugPrint('Erreur recupererEquipeCourante: $e');
      return null;
    }
  }

  /// Crée une nouvelle équipe avec les deux membres donnés.
  /// Retourne l'ID de l'équipe créée.
  Future<String> creerEquipe(List<String> membres) async {
    // Générer un ID unique basé sur les UIDs triés
    final idsSorted = List<String>.from(membres)..sort();
    final equipeId = 'equipe_${idsSorted[0]}_${idsSorted[1]}';

    final docRef = _firestore.collection('equipes').doc(equipeId);
    final doc = await docRef.get();

    if (!doc.exists) {
      // Créer le document équipe
      await docRef.set({
        'id': equipeId,
        'membres': membres,
        'creeLe': FieldValue.serverTimestamp(),
        'misAJourLe': FieldValue.serverTimestamp(),
      });
    } else {
      // L'équipe existe déjà, on met à jour la liste des membres
      final existingData = doc.data() as Map<String, dynamic>;
      final existingMembres = List<String>.from(existingData['membres'] as List? ?? []);
      
      // Ajouter les nouveaux membres qui ne sont pas déjà présents
      for (final uid in membres) {
        if (!existingMembres.contains(uid)) {
          existingMembres.add(uid);
        }
      }

      await docRef.update({
        'membres': existingMembres,
        'misAJourLe': FieldValue.serverTimestamp(),
      });
    }

    return equipeId;
  }

  /// Ajoute un membre à une équipe existante.
  /// Met à jour le document equipe ET le profil de l'utilisateur ajouté.
  Future<void> ajouterMembreAEquipe({
    required String equipeId,
    required String nouvelUid,
  }) async {
    final batch = _firestore.batch();

    // 1. Ajouter l'UID à la liste des membres de l'équipe
    batch.update(
      _firestore.collection('equipes').doc(equipeId),
      {
        'membres': FieldValue.arrayUnion([nouvelUid]),
        'misAJourLe': FieldValue.serverTimestamp(),
      },
    );

    // 2. Mettre à jour le profil du nouvel arrivant avec l'idEquipe
    batch.update(
      _firestore.collection('users').doc(nouvelUid),
      {'idEquipe': equipeId},
    );

    await batch.commit();
  }

  /// Vérifie si un utilisateur a déjà une équipe.
  Future<bool> aDejaUneEquipe(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final equipeId = doc.data()?['idEquipe'] as String?;
      return equipeId != null && equipeId.isNotEmpty;
    } catch (e) {
      debugPrint('Erreur aDejaUneEquipe: $e');
      return false;
    }
  }

  /// Récupère les infos de plusieurs utilisateurs par leurs UIDs.
  Future<Map<String, Map<String, dynamic>?>> recupererInfosMembres(
      List<String> uids) async {
    final Map<String, Map<String, dynamic>?> result = {};
    for (final uid in uids) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        result[uid] = doc.data();
      } catch (_) {
        result[uid] = null;
      }
    }
    return result;
  }

  /// Stream en temps réel d'une équipe par son ID.
  Stream<DocumentSnapshot> ecouterEquipe(String equipeId) {
    return _firestore.collection('equipes').doc(equipeId).snapshots();
  }
}