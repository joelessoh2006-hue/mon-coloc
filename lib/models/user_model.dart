import 'package:cloud_firestore/cloud_firestore.dart';

enum StatutLogement {
  aDejaUnLogement,
  chercheUnLogement,
}

enum Sexe {
  homme,
  femme,
}

enum StatutAnimaux {
  non,
  enAPossession,
  tolere,
}

enum HoraireRevision {
  jour,
  nuit,
  flexible,
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
  final Sexe sexe;
  final bool accepteMixite;

  // Habitudes de vie (Étape 3)
  final Proprete proprete;
  final RythmeDeVie rythmeDeVie;
  final bool fumeur;
  final StatutAnimaux statutAnimaux;
  final String? typeAnimaux;
  final bool bruitsFortsVolume;
  final bool appelsFrequents;
  final bool soireesAmis;
  final bool besoinSilence;
  final HoraireRevision horaireRevision;

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
    required this.sexe,
    required this.accepteMixite,
    required this.proprete,
    required this.rythmeDeVie,
    required this.fumeur,
    required this.statutAnimaux,
    this.typeAnimaux,
    required this.bruitsFortsVolume,
    required this.appelsFrequents,
    required this.soireesAmis,
    required this.besoinSilence,
    required this.horaireRevision,
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
      'sexe': sexe.name,
      'accepteMixite': accepteMixite,
      'proprete': proprete.name,
      'rythmeDeVie': rythmeDeVie.name,
      'fumeur': fumeur,
      'statutAnimaux': statutAnimaux.name,
      'typeAnimaux': typeAnimaux,
      'bruitsFortsVolume': bruitsFortsVolume,
      'appelsFrequents': appelsFrequents,
      'soireesAmis': soireesAmis,
      'besoinSilence': besoinSilence,
      'horaireRevision': horaireRevision.name,
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
      sexe: Sexe.values.firstWhere(
        (e) => e.name == data['sexe'],
      ),
      accepteMixite: data['accepteMixite'] as bool,
      proprete: Proprete.values.firstWhere(
        (e) => e.name == data['proprete'],
      ),
      rythmeDeVie: RythmeDeVie.values.firstWhere(
        (e) => e.name == data['rythmeDeVie'],
      ),
      fumeur: data['fumeur'] as bool,
      statutAnimaux: StatutAnimaux.values.firstWhere(
        (e) => e.name == data['statutAnimaux'],
      ),
      typeAnimaux: data['typeAnimaux'] as String?,
      bruitsFortsVolume: data['bruitsFortsVolume'] as bool,
      appelsFrequents: data['appelsFrequents'] as bool,
      soireesAmis: data['soireesAmis'] as bool,
      besoinSilence: data['besoinSilence'] as bool,
      horaireRevision: HoraireRevision.values.firstWhere(
        (e) => e.name == data['horaireRevision'],
      ),
      dateInscription: (data['dateInscription'] as Timestamp).toDate(),
    );
  }
}