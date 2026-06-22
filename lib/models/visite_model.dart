import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle pour une demande de visite de logement.
/// Stocké dans la collection Firestore 'visites'.
class VisiteModel {
  final String id;
  final String studentId;
  final String studentName;
  final String bailleurId;
  final String logementId;
  final String logementTitle;
  final DateTime dateVisite;
  final String status; // 'en_attente', 'confirme', 'refuse'
  final DateTime creeLe;

  VisiteModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.bailleurId,
    required this.logementId,
    required this.logementTitle,
    required this.dateVisite,
    this.status = 'en_attente',
    DateTime? creeLe,
  }) : creeLe = creeLe ?? DateTime.now();

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'bailleurId': bailleurId,
      'logementId': logementId,
      'logementTitle': logementTitle,
      'dateVisite': Timestamp.fromDate(dateVisite),
      'status': status,
      'creeLe': Timestamp.fromDate(creeLe),
    };
  }

  factory VisiteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisiteModel(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? 'Étudiant',
      bailleurId: data['bailleurId'] as String? ?? '',
      logementId: data['logementId'] as String? ?? '',
      logementTitle: data['logementTitle'] as String? ?? 'Logement',
      dateVisite: data['dateVisite'] != null
          ? (data['dateVisite'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] as String? ?? 'en_attente',
      creeLe: data['creeLe'] != null
          ? (data['creeLe'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  VisiteModel copyWith({String? status, DateTime? dateVisite}) {
    return VisiteModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      bailleurId: bailleurId,
      logementId: logementId,
      logementTitle: logementTitle,
      dateVisite: dateVisite ?? this.dateVisite,
      status: status ?? this.status,
      creeLe: creeLe,
    );
  }
}