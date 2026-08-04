import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service pour gérer la logique métier liée aux locations.
class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Génère les échéances de loyer pour une location donnée.
  ///
  /// Crée un document pour chaque mois dans la sous-collection 'echeances'
  /// de la location spécifiée, en utilisant une opération batch pour l'efficacité.
  ///
  /// [locationId]: L'ID du document dans la collection 'locations'.
  /// [loyerMensuel]: Le montant du loyer pour chaque échéance.
  /// [nombreDeMois]: Le nombre d'échéances à créer (généralement 12 pour un an).
  Future<void> genererEcheancesLoyer({
    required String locationId,
    required double loyerMensuel,
    required int nombreDeMois,
  }) async {
    try {
      final batch = _firestore.batch();
      final echeancesRef = _firestore
          .collection('locations')
          .doc(locationId)
          .collection('echeances');
      final dateDeDepart = DateTime.now();

      for (int i = 0; i < nombreDeMois; i++) {
        final dateEcheance = DateTime(
          dateDeDepart.year,
          dateDeDepart.month + i,
          1,
        );
        final docRef = echeancesRef.doc(
          '${dateEcheance.year}-${dateEcheance.month.toString().padLeft(2, '0')}',
        );

        batch.set(docRef, {
          'mois': dateEcheance.month,
          'annee': dateEcheance.year,
          'montant': loyerMensuel,
          'statut': 'en_attente',
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Erreur lors de la génération des échéances de loyer : $e");
      // Propage l'erreur pour qu'elle puisse être gérée par l'appelant.
      rethrow;
    }
  }
}
