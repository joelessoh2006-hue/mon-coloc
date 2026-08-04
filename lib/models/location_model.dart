import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String id;
  final String etudiantId;
  final String bailleurId;
  final String logementId;
  final bool cautionPayee;
  final int montantCaution;
  final int loyerMensuel;
  final String statut;
  final DateTime dateDebut;

  LocationModel({
    required this.id,
    required this.etudiantId,
    required this.bailleurId,
    required this.logementId,
    required this.cautionPayee,
    required this.montantCaution,
    required this.loyerMensuel,
    required this.statut,
    required this.dateDebut,
  });

  factory LocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationModel(
      id: doc.id,
      etudiantId: data['etudiantId'] as String,
      bailleurId: data['bailleurId'] as String,
      logementId: data['logementId'] as String,
      cautionPayee: data['cautionPayee'] as bool? ?? false,
      montantCaution: data['montantCaution'] as int? ?? 0,
      loyerMensuel: data['loyerMensuel'] as int? ?? 0,
      statut: data['statut'] as String? ?? 'inactive',
      dateDebut: (data['dateDebut'] as Timestamp).toDate(),
    );
  }
}
