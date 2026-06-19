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

  /// Rôle : 'etudiant' ou 'bailleur'
  final String role;

  /// Vérification du compte (false par défaut, passe à true après validation)
  final bool estVerifie;

  /// URL de la photo de profil (Firebase Storage)
  final String? photoUrl;

  /// Filière d'études (étudiant)
  final String? filiere;

  /// Courte biographie / présentation
  final String? biographie;

  /// URL du document justificatif (Firebase Storage)
  final String? justificatifUrl;

  // Critères de logement (Étape 2 — uniquement pour étudiants)
  final double budgetMaxFCFA;
  final List<String> quartierCible; // Quartier(s) ciblé(s) à Abidjan
  final StatutLogement statutLogement;
  final Sexe sexe;
  final bool accepteMixite;

  /// Zone de recherche (affinage quartier)
  final String? zoneRecherche;

  /// Type de logement souhaité (Appartement, Studio, Chambre, etc.)
  final String? typeLogement;

  // Habitudes de vie (Étape 3 — uniquement pour étudiants)
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

  /// Niveau de sociabilité (1-5)
  final int? niveauSociabilite;

  final DateTime dateInscription;

  UserModel({
    required this.uid,
    required this.email,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.ecoleUniversite,
    this.role = 'etudiant',
    this.estVerifie = false,
    this.photoUrl,
    this.filiere,
    this.biographie,
    this.justificatifUrl,
    required this.budgetMaxFCFA,
    required this.quartierCible,
    required this.statutLogement,
    required this.sexe,
    required this.accepteMixite,
    this.zoneRecherche,
    this.typeLogement,
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
    this.niveauSociabilite,
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
      'role': role,
      'estVerifie': estVerifie,
      'photoUrl': photoUrl,
      'filiere': filiere,
      'biographie': biographie,
      'justificatifUrl': justificatifUrl,
      'budgetMaxFCFA': budgetMaxFCFA,
      'quartierCible': quartierCible,
      'statutLogement': statutLogement.name,
      'sexe': sexe.name,
      'accepteMixite': accepteMixite,
      'zoneRecherche': zoneRecherche,
      'typeLogement': typeLogement,
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
      'niveauSociabilite': niveauSociabilite,
      'dateInscription': Timestamp.fromDate(dateInscription),
    };
  }

  /// Convertit un champ Firestore potentiellement String ou List en `List<String>`.
  static List<String> safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value.map((e) => e.toString()));
    if (value is String) return [value];
    return [];
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
      role: data['role'] as String? ?? 'etudiant',
      estVerifie: data['estVerifie'] as bool? ?? false,
      photoUrl: data['photoUrl'] as String?,
      filiere: data['filiere'] as String?,
      biographie: data['biographie'] as String?,
      justificatifUrl: data['justificatifUrl'] as String?,
      budgetMaxFCFA: (data['budgetMaxFCFA'] as num?)?.toDouble() ?? 0,
      quartierCible: safeStringList(data['quartierCible']),
      statutLogement: StatutLogement.values.firstWhere(
        (e) => e.name == data['statutLogement'],
        orElse: () => StatutLogement.chercheUnLogement,
      ),
      sexe: Sexe.values.firstWhere(
        (e) => e.name == data['sexe'],
        orElse: () => Sexe.homme,
      ),
      accepteMixite: data['accepteMixite'] as bool? ?? false,
      zoneRecherche: data['zoneRecherche'] as String?,
      typeLogement: data['typeLogement'] as String?,
      proprete: Proprete.values.firstWhere(
        (e) => e.name == data['proprete'],
        orElse: () => Proprete.propre,
      ),
      rythmeDeVie: RythmeDeVie.values.firstWhere(
        (e) => e.name == data['rythmeDeVie'],
        orElse: () => RythmeDeVie.leveTot,
      ),
      fumeur: data['fumeur'] as bool? ?? false,
      statutAnimaux: StatutAnimaux.values.firstWhere(
        (e) => e.name == data['statutAnimaux'],
        orElse: () => StatutAnimaux.non,
      ),
      typeAnimaux: data['typeAnimaux'] as String?,
      bruitsFortsVolume: data['bruitsFortsVolume'] as bool? ?? false,
      appelsFrequents: data['appelsFrequents'] as bool? ?? false,
      soireesAmis: data['soireesAmis'] as bool? ?? false,
      besoinSilence: data['besoinSilence'] as bool? ?? false,
      horaireRevision: HoraireRevision.values.firstWhere(
        (e) => e.name == data['horaireRevision'],
        orElse: () => HoraireRevision.flexible,
      ),
      niveauSociabilite: data['niveauSociabilite'] as int?,
      dateInscription: data['dateInscription'] != null
          ? (data['dateInscription'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Retourne une copie avec les champs modifiés
  UserModel copyWith({
    String? uid,
    String? email,
    String? nom,
    String? prenom,
    String? telephone,
    String? ecoleUniversite,
    String? role,
    bool? estVerifie,
    String? photoUrl,
    String? filiere,
    String? biographie,
    String? justificatifUrl,
    double? budgetMaxFCFA,
    List<String>? quartierCible,
    StatutLogement? statutLogement,
    Sexe? sexe,
    bool? accepteMixite,
    String? zoneRecherche,
    String? typeLogement,
    Proprete? proprete,
    RythmeDeVie? rythmeDeVie,
    bool? fumeur,
    StatutAnimaux? statutAnimaux,
    String? typeAnimaux,
    bool? bruitsFortsVolume,
    bool? appelsFrequents,
    bool? soireesAmis,
    bool? besoinSilence,
    HoraireRevision? horaireRevision,
    int? niveauSociabilite,
    DateTime? dateInscription,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      telephone: telephone ?? this.telephone,
      ecoleUniversite: ecoleUniversite ?? this.ecoleUniversite,
      role: role ?? this.role,
      estVerifie: estVerifie ?? this.estVerifie,
      photoUrl: photoUrl ?? this.photoUrl,
      filiere: filiere ?? this.filiere,
      biographie: biographie ?? this.biographie,
      justificatifUrl: justificatifUrl ?? this.justificatifUrl,
      budgetMaxFCFA: budgetMaxFCFA ?? this.budgetMaxFCFA,
      quartierCible: quartierCible ?? this.quartierCible,
      statutLogement: statutLogement ?? this.statutLogement,
      sexe: sexe ?? this.sexe,
      accepteMixite: accepteMixite ?? this.accepteMixite,
      zoneRecherche: zoneRecherche ?? this.zoneRecherche,
      typeLogement: typeLogement ?? this.typeLogement,
      proprete: proprete ?? this.proprete,
      rythmeDeVie: rythmeDeVie ?? this.rythmeDeVie,
      fumeur: fumeur ?? this.fumeur,
      statutAnimaux: statutAnimaux ?? this.statutAnimaux,
      typeAnimaux: typeAnimaux ?? this.typeAnimaux,
      bruitsFortsVolume: bruitsFortsVolume ?? this.bruitsFortsVolume,
      appelsFrequents: appelsFrequents ?? this.appelsFrequents,
      soireesAmis: soireesAmis ?? this.soireesAmis,
      besoinSilence: besoinSilence ?? this.besoinSilence,
      horaireRevision: horaireRevision ?? this.horaireRevision,
      niveauSociabilite: niveauSociabilite ?? this.niveauSociabilite,
      dateInscription: dateInscription ?? this.dateInscription,
    );
  }
}