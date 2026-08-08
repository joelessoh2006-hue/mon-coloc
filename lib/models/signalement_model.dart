import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle de données pour un signalement dans Firestore.
class SignalementModel {
  final String id;
  final String signalePar; // UID de l'auteur du signalement
  final String cibleId; // ID de l'élément (utilisateur, logement) signalé
  final String typeCible; // 'utilisateur', 'logement', etc.
  final String motif;
  final DateTime date;
  final String statut; // 'en_attente', 'traite', 'ignore'

  SignalementModel({
    required this.id,
    required this.signalePar,
    required this.cibleId,
    required this.typeCible,
    required this.motif,
    required this.date,
    this.statut = 'en_attente',
  });

  /// Convertit le modèle en une Map pour l'écriture dans Firestore.
  /// La date est convertie en Timestamp.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'signalePar': signalePar,
      'cibleId': cibleId,
      'typeCible': typeCible,
      'motif': motif,
      'date': Timestamp.fromDate(date),
      'statut': statut,
    };
  }

  /// Crée une instance de SignalementModel à partir d'un DocumentSnapshot Firestore.
  factory SignalementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return SignalementModel(
      id: doc.id,
      signalePar: data['signalePar'] as String? ?? '',
      cibleId: data['cibleId'] as String? ?? '',
      typeCible: data['typeCible'] as String? ?? 'inconnu',
      motif: data['motif'] as String? ?? 'Non spécifié',
      date: (data['date'] as Timestamp? ?? Timestamp.now()).toDate(),
      statut: data['statut'] as String? ?? 'en_attente',
    );
  }
}
