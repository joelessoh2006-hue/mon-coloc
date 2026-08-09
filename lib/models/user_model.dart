import 'package:cloud_firestore/cloud_firestore.dart';

// --- ÉNUMÉRATIONS COMPLÈTES ---
enum StatutLogement { chercheUnLogement, aDejaUnLogement }
enum Sexe { homme, femme }
enum Proprete { tresPropre, propre, moyen }
enum RythmeDeVie { leveTot, coucheTard, flexible }
enum StatutAnimaux { oui, non, enAPossession, tolere }
enum HoraireRevision { matinal, soir, flexible, jour, nuit }

class UserModel {
  final String uid;
  final String email;
  final String nom;
  final String prenom;
  final String telephone;
  final String role; // 'etudiant' ou 'bailleur'
  final bool estVerifie;
  
  // Champs profil / préférences étudiant
  final String ecoleUniversite;
  final String filiere;
  final String biographie;
  final String photoUrl;
  final double budgetMaxFCFA;
  final List<String> quartierCible;
  final String zoneRecherche;
  final String typeLogement;
  
  // Logement et critères de vie
  final StatutLogement? statutLogement;
  final Sexe? sexe;
  final Proprete proprete;
  final RythmeDeVie? rythmeDeVie;
  final StatutAnimaux statutAnimaux;
  final HoraireRevision horaireRevision;
  final bool fumeur;
  final bool besoinSilence;
  final bool accepteMixite;
  final int niveauSociabilite;

  // Habitudes spécifiques
  final bool bruitsFortsVolume;
  final bool soireesAmis;
  final bool appelsFrequents;

  // Infos logement (si aDejaUnLogement)
  final String? logementQuartier;
  final double? logementLoyerTotal;
  final double? logementPartColoc;
  final String? logementDescription;
  final List<String> logementPhotos;
  final List<String>? habitudesQuotidiennes;
  final String? genreColocataireRecherche;

  // Justificatifs
  final String? justificatifIdentiteUrl;
  final String? justificatifLoyerUrl;
  final String? justificatifBailUrl;
  final List<String> documentsUrls;

  // Paramètres de compatibilité pour les formulaires d'inscription / écrans
  final String? typeAnimaux;
  final DateTime? dateNaissance;
  final int? _ageParam;
  final bool? aDejaUnLogementParam;
  final DateTime? dateInscription;

  UserModel({
    required this.uid,
    required this.email,
    required this.nom,
    required this.prenom,
    this.telephone = '',
    required this.role,
    required this.estVerifie,
    this.ecoleUniversite = '',
    this.filiere = '',
    this.biographie = '',
    this.photoUrl = '',
    this.budgetMaxFCFA = 0.0,
    this.quartierCible = const [],
    this.zoneRecherche = '',
    this.typeLogement = '',
    this.statutLogement,
    this.sexe,
    this.proprete = Proprete.propre,
    this.rythmeDeVie,
    this.statutAnimaux = StatutAnimaux.non,
    this.horaireRevision = HoraireRevision.flexible,
    this.fumeur = false,
    this.besoinSilence = false,
    this.accepteMixite = true,
    this.niveauSociabilite = 3,
    this.bruitsFortsVolume = false,
    this.soireesAmis = false,
    this.appelsFrequents = false,
    this.logementQuartier,
    this.logementLoyerTotal,
    this.logementPartColoc,
    this.logementDescription,
    this.logementPhotos = const [],
    this.habitudesQuotidiennes,
    this.genreColocataireRecherche,
    this.justificatifIdentiteUrl,
    this.justificatifLoyerUrl,
    this.justificatifBailUrl,
    this.documentsUrls = const [],
    this.typeAnimaux,
    this.dateNaissance,
    int? age,
    bool? aDejaUnLogement,
    this.dateInscription,
  })  : _ageParam = age,
        aDejaUnLogementParam = aDejaUnLogement;

  bool get aDejaUnLogement => 
      aDejaUnLogementParam ?? (statutLogement == StatutLogement.aDejaUnLogement);

  int get age => _ageParam ?? 22; 

  static List<String> safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] ?? '',
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      telephone: map['telephone'] ?? '',
      role: map['role'] ?? 'etudiant',
      estVerifie: map['estVerifie'] ?? false,
      ecoleUniversite: map['ecoleUniversite'] ?? '',
      filiere: map['filiere'] ?? '',
      biographie: map['biographie'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      budgetMaxFCFA: (map['budgetMaxFCFA'] as num?)?.toDouble() ?? 0.0,
      quartierCible: safeStringList(map['quartierCible']),
      zoneRecherche: map['zoneRecherche'] ?? '',
      typeLogement: map['typeLogement'] ?? '',
      statutLogement: map['statutLogement'] != null
          ? StatutLogement.values.firstWhere(
              (e) => e.name == map['statutLogement'],
              orElse: () => StatutLogement.chercheUnLogement,
            )
          : null,
      sexe: map['sexe'] != null
          ? Sexe.values.firstWhere((e) => e.name == map['sexe'], orElse: () => Sexe.homme)
          : null,
      proprete: map['proprete'] != null
          ? Proprete.values.firstWhere((e) => e.name == map['proprete'], orElse: () => Proprete.propre)
          : Proprete.propre,
      rythmeDeVie: map['rythmeDeVie'] != null
          ? RythmeDeVie.values.firstWhere((e) => e.name == map['rythmeDeVie'], orElse: () => RythmeDeVie.flexible)
          : null,
      statutAnimaux: map['statutAnimaux'] != null
          ? StatutAnimaux.values.firstWhere((e) => e.name == map['statutAnimaux'], orElse: () => StatutAnimaux.non)
          : StatutAnimaux.non,
      horaireRevision: map['horaireRevision'] != null
          ? HoraireRevision.values.firstWhere((e) => e.name == map['horaireRevision'], orElse: () => HoraireRevision.flexible)
          : HoraireRevision.flexible,
      fumeur: map['fumeur'] ?? false,
      besoinSilence: map['besoinSilence'] ?? false,
      accepteMixite: map['accepteMixite'] ?? true,
      niveauSociabilite: map['niveauSociabilite'] ?? 3,
      bruitsFortsVolume: map['bruitsFortsVolume'] ?? false,
      soireesAmis: map['soireesAmis'] ?? false,
      appelsFrequents: map['appelsFrequents'] ?? false,
      logementQuartier: map['logementQuartier'],
      logementLoyerTotal: (map['logementLoyerTotal'] as num?)?.toDouble(),
      logementPartColoc: (map['logementPartColoc'] as num?)?.toDouble(),
      logementDescription: map['logementDescription'],
      logementPhotos: safeStringList(map['logementPhotos']),
      genreColocataireRecherche: map['genreColocataireRecherche'],
      habitudesQuotidiennes: map['habitudesQuotidiennes'] != null ? safeStringList(map['habitudesQuotidiennes']) : null,
      justificatifIdentiteUrl: map['justificatifIdentiteUrl'],
      justificatifLoyerUrl: map['justificatifLoyerUrl'],
      justificatifBailUrl: map['justificatifBailUrl'],
      documentsUrls: safeStringList(map['documentsUrls']),
      dateNaissance: map['dateNaissance'] != null 
          ? (map['dateNaissance'] is Timestamp 
              ? (map['dateNaissance'] as Timestamp).toDate() 
              : DateTime.tryParse(map['dateNaissance'].toString()))
          : null,
      dateInscription: map['dateInscription'] != null
          ? (map['dateInscription'] is Timestamp
              ? (map['dateInscription'] as Timestamp).toDate()
              : DateTime.tryParse(map['dateInscription'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'role': role,
      'estVerifie': estVerifie,
      'ecoleUniversite': ecoleUniversite,
      'filiere': filiere,
      'biographie': biographie,
      'photoUrl': photoUrl,
      'budgetMaxFCFA': budgetMaxFCFA,
      'quartierCible': quartierCible,
      'zoneRecherche': zoneRecherche,
      'typeLogement': typeLogement,
      'statutLogement': statutLogement?.name,
      'sexe': sexe?.name,
      'proprete': proprete.name,
      'rythmeDeVie': rythmeDeVie?.name,
      'statutAnimaux': statutAnimaux.name,
      'horaireRevision': horaireRevision.name,
      'fumeur': fumeur,
      'besoinSilence': besoinSilence,
      'accepteMixite': accepteMixite,
      'niveauSociabilite': niveauSociabilite,
      'bruitsFortsVolume': bruitsFortsVolume,
      'soireesAmis': soireesAmis,
      'appelsFrequents': appelsFrequents,
      'logementQuartier': logementQuartier,
      'logementLoyerTotal': logementLoyerTotal,
      'logementPartColoc': logementPartColoc,
      'logementDescription': logementDescription,
      'logementPhotos': logementPhotos,
      'genreColocataireRecherche': genreColocataireRecherche,
      'habitudesQuotidiennes': habitudesQuotidiennes,
      'justificatifIdentiteUrl': justificatifIdentiteUrl,
      'justificatifLoyerUrl': justificatifLoyerUrl,
      'justificatifBailUrl': justificatifBailUrl,
      'documentsUrls': documentsUrls,
      'typeAnimaux': typeAnimaux,
      'dateNaissance': dateNaissance,
      'dateInscription': dateInscription,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  UserModel copyWith({
    String? email,
    String? nom,
    String? prenom,
    String? telephone,
    String? role,
    bool? estVerifie,
    String? ecoleUniversite,
    String? filiere,
    String? biographie,
    String? photoUrl,
    double? budgetMaxFCFA,
    List<String>? quartierCible,
    String? zoneRecherche,
    String? typeLogement,
    StatutLogement? statutLogement,
    Sexe? sexe,
    Proprete? proprete,
    RythmeDeVie? rythmeDeVie,
    StatutAnimaux? statutAnimaux,
    HoraireRevision? horaireRevision,
    bool? fumeur,
    bool? besoinSilence,
    bool? accepteMixite,
    int? niveauSociabilite,
    bool? bruitsFortsVolume,
    bool? soireesAmis,
    bool? appelsFrequents,
    String? logementQuartier,
    double? logementLoyerTotal,
    double? logementPartColoc,
    String? logementDescription,
    List<String>? logementPhotos,
    String? genreColocataireRecherche,
    List<String>? habitudesQuotidiennes,
    String? justificatifIdentiteUrl,
    String? justificatifLoyerUrl,
    String? justificatifBailUrl,
    List<String>? documentsUrls,
    String? typeAnimaux,
    DateTime? dateNaissance,
    int? age,
    bool? aDejaUnLogement,
    DateTime? dateInscription,
  }) {
    return UserModel(
      uid: this.uid,
      email: email ?? this.email,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      estVerifie: estVerifie ?? this.estVerifie,
      ecoleUniversite: ecoleUniversite ?? this.ecoleUniversite,
      filiere: filiere ?? this.filiere,
      biographie: biographie ?? this.biographie,
      photoUrl: photoUrl ?? this.photoUrl,
      budgetMaxFCFA: budgetMaxFCFA ?? this.budgetMaxFCFA,
      quartierCible: quartierCible ?? this.quartierCible,
      zoneRecherche: zoneRecherche ?? this.zoneRecherche,
      typeLogement: typeLogement ?? this.typeLogement,
      statutLogement: statutLogement ?? this.statutLogement,
      sexe: sexe ?? this.sexe,
      proprete: proprete ?? this.proprete,
      rythmeDeVie: rythmeDeVie ?? this.rythmeDeVie,
      statutAnimaux: statutAnimaux ?? this.statutAnimaux,
      horaireRevision: horaireRevision ?? this.horaireRevision,
      fumeur: fumeur ?? this.fumeur,
      besoinSilence: besoinSilence ?? this.besoinSilence,
      accepteMixite: accepteMixite ?? this.accepteMixite,
      niveauSociabilite: niveauSociabilite ?? this.niveauSociabilite,
      bruitsFortsVolume: bruitsFortsVolume ?? this.bruitsFortsVolume,
      soireesAmis: soireesAmis ?? this.soireesAmis,
      appelsFrequents: appelsFrequents ?? this.appelsFrequents,
      logementQuartier: logementQuartier ?? this.logementQuartier,
      logementLoyerTotal: logementLoyerTotal ?? this.logementLoyerTotal,
      logementPartColoc: logementPartColoc ?? this.logementPartColoc,
      logementDescription: logementDescription ?? this.logementDescription,
      logementPhotos: logementPhotos ?? this.logementPhotos,
      genreColocataireRecherche: genreColocataireRecherche ?? this.genreColocataireRecherche,
      habitudesQuotidiennes: habitudesQuotidiennes ?? this.habitudesQuotidiennes,
      justificatifIdentiteUrl: justificatifIdentiteUrl ?? this.justificatifIdentiteUrl,
      justificatifLoyerUrl: justificatifLoyerUrl ?? this.justificatifLoyerUrl,
      justificatifBailUrl: justificatifBailUrl ?? this.justificatifBailUrl,
      documentsUrls: documentsUrls ?? this.documentsUrls,
      typeAnimaux: typeAnimaux ?? this.typeAnimaux,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      age: age ?? this._ageParam,
      aDejaUnLogement: aDejaUnLogement ?? this.aDejaUnLogementParam,
      dateInscription: dateInscription ?? this.dateInscription,
    );
  }
}