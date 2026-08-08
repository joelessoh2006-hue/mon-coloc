import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/signalement_model.dart';

class SignalementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Envoie un nouveau signalement dans Firestore
  Future<void> envoyerSignalement({
    required String cibleId,
    required String typeCible,
    required String motif,
  }) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("Utilisateur non connecté");

      // Création d'une instance du modèle (sans ID, Firestore le générera)
      final signalement = SignalementModel(
        id: '', // Laissé vide, sera rempli par l'ID du document Firestore
        signalePar: currentUser.uid,
        cibleId: cibleId,
        typeCible: typeCible,
        motif: motif,
        date: DateTime.now(),
        statut: 'en_attente',
      );

      // Enregistrement dans la collection 'signalements'
      await _db.collection('signalements').add(signalement.toMap());
    } catch (e) {
      print("Erreur lors de l'envoi du signalement : $e");
      rethrow;
    }
  }
}