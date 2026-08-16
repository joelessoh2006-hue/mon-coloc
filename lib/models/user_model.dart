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
  final String role; // 'etudiant', 'bailleur' ou 'admin'
  final bool estVerifie;
  final bool estBloque;

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

  // Justificatifs & Vérification
  final String? statutVerification;
  final String? justificatifIdentiteUrl;
  final String? justificatifLoyerUrl;
  final String? justificatifBailUrl;
  final List<String> documentsUrls;

  // Paramètres complémentaires
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
    this.estBloque = false,
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
    this.statutVerification = 'en_attente',
    this.justificatifIdentiteUrl = '',
    this.justificatifLoyerUrl = '',
    this.justificatifBailUrl = '',
    this.documentsUrls = const [],
    this.typeAnimaux,
    this.dateNaissance,
    int? age,
    bool? aDejaUnLogement,
    this.dateInscription,
  }) : _ageParam = age,
       aDejaUnLogementParam = aDejaUnLogement;

  bool get aDejaUnLogement =>
      aDejaUnLogementParam ??
      (statutLogement == StatutLogement.aDejaUnLogement);

  int get age {
    if (_ageParam != null) return _ageParam;
    if (dateNaissance != null) return calculerAge(dateNaissance!);
    return 22;
  }

  /// Calcule l'âge exact à partir d'une date de naissance.
  static int calculerAge(DateTime dateNaissance) {
    final now = DateTime.now();
    int age = now.year - dateNaissance.year;
    if (now.month < dateNaissance.month ||
        (now.month == dateNaissance.month && now.day < dateNaissance.day)) {
      age--;
    }
    return age;
  }

  static List<String> safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      return [value];
    }
    return [];
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    final statutLogementRaw = map['statutLogement'];
    final bool aDejaUnLogementCalculated =
        (map['aDejaUnLogement'] as bool? ?? false) ||
        statutLogementRaw == 'aDejaUnLogement' ||
        statutLogementRaw == 'StatutLogement.aDejaUnLogement';

    // Rétrocompatibilité pour la clé du justificatif principal
    final String mainJustificatif =
        map['justificatifIdentiteUrl'] ?? map['justificatifUrl'] ?? '';

    return UserModel(
      uid: id,
      email: map['email'] ?? '',
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      telephone: map['telephone'] ?? '',
      role: map['role'] ?? 'etudiant',
      estVerifie: map['estVerifie'] ?? false,
      estBloque: map['estBloque'] ?? false,
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
              (e) =>
                  e.name == map['statutLogement'] ||
                  e.toString() == map['statutLogement'],
              orElse: () => StatutLogement.chercheUnLogement,
            )
          : null,
      sexe: map['sexe'] != null
          ? Sexe.values.firstWhere(
              (e) => e.name == map['sexe'] || e.toString() == map['sexe'],
              orElse: () => Sexe.homme,
            )
          : null,
      proprete: map['proprete'] != null
          ? Proprete.values.firstWhere(
              (e) =>
                  e.name == map['proprete'] || e.toString() == map['proprete'],
              orElse: () => Proprete.propre,
            )
          : Proprete.propre,
      rythmeDeVie: map['rythmeDeVie'] != null
          ? RythmeDeVie.values.firstWhere(
              (e) =>
                  e.name == map['rythmeDeVie'] ||
                  e.toString() == map['rythmeDeVie'],
              orElse: () => RythmeDeVie.flexible,
            )
          : null,
      statutAnimaux: map['statutAnimaux'] != null
          ? StatutAnimaux.values.firstWhere(
              (e) =>
                  e.name == map['statutAnimaux'] ||
                  e.toString() == map['statutAnimaux'],
              orElse: () => StatutAnimaux.non,
            )
          : StatutAnimaux.non,
      horaireRevision: map['horaireRevision'] != null
          ? HoraireRevision.values.firstWhere(
              (e) =>
                  e.name == map['horaireRevision'] ||
                  e.toString() == map['horaireRevision'],
              orElse: () => HoraireRevision.flexible,
            )
          : HoraireRevision.flexible,
      fumeur: map['fumeur'] ?? false,
      besoinSilence: map['besoinSilence'] ?? false,
      accepteMixite: map['accepteMixite'] ?? true,
      niveauSociabilite: map['niveauSociabilite'] ?? 3,
      bruitsFortsVolume: map['bruitsFortsVolume'] ?? false,
      soireesAmis: map['soireesAmis'] ?? false,
      appelsFrequents: map['appelsFrequents'] ?? false,
      aDejaUnLogement: aDejaUnLogementCalculated,
      logementQuartier: map['logementQuartier'],
      logementLoyerTotal: (map['logementLoyerTotal'] as num?)?.toDouble(),
      logementPartColoc: (map['logementPartColoc'] as num?)?.toDouble(),
      logementDescription: map['logementDescription'],
      logementPhotos: safeStringList(map['logementPhotos']),
      genreColocataireRecherche: map['genreColocataireRecherche'],
      habitudesQuotidiennes: map['habitudesQuotidiennes'] != null
          ? safeStringList(map['habitudesQuotidiennes'])
          : null,
      statutVerification: map['statutVerification'] ?? 'en_attente',
      justificatifIdentiteUrl: mainJustificatif,
      justificatifLoyerUrl: map['justificatifLoyerUrl'] ?? '',
      justificatifBailUrl: map['justificatifBailUrl'] ?? '',
      documentsUrls: safeStringList(map['documentsUrls']),
      typeAnimaux: map['typeAnimaux'],
      age: map['age'] as int?,
      dateNaissance: map['dateNaissance'] != null
          ? (map['dateNaissance'] is Timestamp
                ? (map['dateNaissance'] as Timestamp).toDate()
                : DateTime.tryParse(map['dateNaissance'].toString()))
          : null,
      dateInscription:
          (map['dateInscription'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'role': role,
      'estVerifie': estVerifie,
      'estBloque': estBloque,
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
      'aDejaUnLogement': aDejaUnLogement,
      'logementQuartier': logementQuartier,
      'logementLoyerTotal': logementLoyerTotal,
      'logementPartColoc': logementPartColoc,
      'logementDescription': logementDescription,
      'logementPhotos': logementPhotos,
      'genreColocataireRecherche': genreColocataireRecherche,
      'habitudesQuotidiennes': habitudesQuotidiennes,
      'statutVerification': statutVerification,
      'justificatifIdentiteUrl': justificatifIdentiteUrl,
      'justificatifUrl': justificatifIdentiteUrl, // Rétrocompatibilité
      'justificatifLoyerUrl': justificatifLoyerUrl,
      'justificatifBailUrl': justificatifBailUrl,
      'documentsUrls': documentsUrls,
      'typeAnimaux': typeAnimaux,
      'dateNaissance': dateNaissance != null
          ? Timestamp.fromDate(dateNaissance!)
          : null,
      'dateInscription': dateInscription != null
          ? Timestamp.fromDate(dateInscription!)
          : null,
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
    bool? estBloque,
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
    String? statutVerification,
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
      uid: uid,
      email: email ?? this.email,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      estVerifie: estVerifie ?? this.estVerifie,
      estBloque: estBloque ?? this.estBloque,
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
      genreColocataireRecherche:
          genreColocataireRecherche ?? this.genreColocataireRecherche,
      habitudesQuotidiennes:
          habitudesQuotidiennes ?? this.habitudesQuotidiennes,
      statutVerification: statutVerification ?? this.statutVerification,
      justificatifIdentiteUrl:
          justificatifIdentiteUrl ?? this.justificatifIdentiteUrl,
      justificatifLoyerUrl: justificatifLoyerUrl ?? this.justificatifLoyerUrl,
      justificatifBailUrl: justificatifBailUrl ?? this.justificatifBailUrl,
      documentsUrls: documentsUrls ?? this.documentsUrls,
      typeAnimaux: typeAnimaux ?? this.typeAnimaux,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      age: age ?? _ageParam,
      aDejaUnLogement: aDejaUnLogement ?? aDejaUnLogementParam,
      dateInscription: dateInscription ?? this.dateInscription,
    );
  }
}
