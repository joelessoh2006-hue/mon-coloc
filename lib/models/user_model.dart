import 'package:cloud_firestore/cloud_firestore.dart';

enum StatutLogement {
  aDejaUnLogement,
  chercheUnLogement,
}

enum RythmeDeVie {
  leveTot,
  coucheTard,
}

enum Proprete {
  tresPropre,
  propre,
  moyen,
}

/// Modèle utilisateur complet pour l'application Mon Coloc.
/// Stocké dans la collection Firestore 'users'.
class UserModel {
  final String uid;
  final String email;
  final String nom;
  final String prenom;
  final String telephone; // format +225
  final String ecoleUniversite;

  // Critères de logement (Étape 2)
  final double budgetMaxFCFA;
  final List<String> quartierCible; // Quartier(s) ciblé(s) à Abidjan
  final StatutLogement statutLogement;

  // Habitudes de vie (Étape 3)
  final Proprete proprete;
  final RythmeDeVie rythmeDeVie;
  final bool fumeur;

  final DateTime dateInscription;

  UserModel({
    required this.uid,
    required this.email,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.ecoleUniversite,
    required this.budgetMaxFCFA,
    required this.quartierCible,
    required this.statutLogement,
    required this.proprete,
    required this.rythmeDeVie,
    required this.fumeur,
    DateTime? dateInscription,
  }) : dateInscription = dateInscription ?? DateTime.now();

  /// Convertit le modèle en un Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'ecoleUniversite': ecoleUniversite,
      'budgetMaxFCFA': budgetMaxFCFA,
      'quartierCible': quartierCible,
      'statutLogement': statutLogement.name,
      'proprete': proprete.name,
      'rythmeDeVie': rythmeDeVie.name,
      'fumeur': fumeur,
      'dateInscription': Timestamp.fromDate(dateInscription),
    };
  }

  /// Crée un UserModel à partir d'un DocumentSnapshot Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] as String,
      email: data['email'] as String,
      nom: data['nom'] as String,
      prenom: data['prenom'] as String,
      telephone: data['telephone'] as String,
      ecoleUniversite: data['ecoleUniversite'] as String,
      budgetMaxFCFA: (data['budgetMaxFCFA'] as num).toDouble(),
      quartierCible: (data['quartierCible'] as List<dynamic>).cast<String>(),
      statutLogement: StatutLogement.values.firstWhere(
        (e) => e.name == data['statutLogement'],
      ),
      proprete: Proprete.values.firstWhere(
        (e) => e.name == data['proprete'],
      ),
      rythmeDeVie: RythmeDeVie.values.firstWhere(
        (e) => e.name == data['rythmeDeVie'],
      ),
      fumeur: data['fumeur'] as bool,
      dateInscription: (data['dateInscription'] as Timestamp).toDate(),
    );
  }
}