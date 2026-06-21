import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant une équipe de colocation.
///
/// Stocké dans la collection Firestore 'equipes'.
/// Une équipe peut contenir 2, 3, 4 membres ou plus selon le logement.
class EquipeModel {
  final String id;
  final List<String> membres; // UIDs des membres
  final DateTime creeLe;
  final DateTime? misAJourLe;

  EquipeModel({
    required this.id,
    required this.membres,
    DateTime? creeLe,
    this.misAJourLe,
  }) : creeLe = creeLe ?? DateTime.now();

  /// Convertit le modèle en un Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'membres': membres,
      'creeLe': Timestamp.fromDate(creeLe),
      'misAJourLe': misAJourLe != null
          ? Timestamp.fromDate(misAJourLe!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// Crée un EquipeModel à partir d'un DocumentSnapshot Firestore
  factory EquipeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EquipeModel(
      id: doc.id,
      membres: List<String>.from(data['membres'] as List? ?? []),
      creeLe: data['creeLe'] != null
          ? (data['creeLe'] as Timestamp).toDate()
          : DateTime.now(),
      misAJourLe: data['misAJourLe'] != null
          ? (data['misAJourLe'] as Timestamp).toDate()
          : null,
    );
  }

  /// Retourne une copie avec les champs modifiés
  EquipeModel copyWith({
    String? id,
    List<String>? membres,
    DateTime? creeLe,
    DateTime? misAJourLe,
  }) {
    return EquipeModel(
      id: id ?? this.id,
      membres: membres ?? this.membres,
      creeLe: creeLe ?? this.creeLe,
      misAJourLe: misAJourLe ?? this.misAJourLe,
    );
  }
}