import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:mon_coloc/screens/chat_screen.dart';
import 'package:mon_coloc/screens/etudiant/profile_detail_screen.dart';
import 'package:mon_coloc/services/matching_service.dart';
import 'package:mon_coloc/services/user_service.dart';

/// Écran "Découvrir" — Affiche les profils étudiants triés par score de matching.
///
/// S'adapte selon le statut logement de l'utilisateur connecté :
/// - Étudiant SANS logement : affiche 2 sous-onglets (sans logement / avec logement)
/// - Étudiant AVEC logement : n'affiche que les étudiants sans logement
class DecouvrirScreen extends StatefulWidget {
  const DecouvrirScreen({super.key});

  @override
  State<DecouvrirScreen> createState() => _DecouvrirScreenState();
}

class _DecouvrirScreenState extends State<DecouvrirScreen>
    with SingleTickerProviderStateMixin {
  final MatchingService _matchingService = MatchingService();
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Utilisateur connecté
  UserModel? _currentUserModel;

  /// Index du sous-onglet actif (0 = sans logement, 1 = avec logement)
  int _sousOngletActif = 0;

  /// Cache pour les informations des utilisateurs
  final Map<String, Map<String, dynamic>?> _userCache = {};

  /// Si false, masque l'onglet "Avec logement" (si l'utilisateur est dans un duo qui a un logement)
  bool _peutVoirOngletAvecLogement = true;

  @override
  void initState() {
    super.initState();
    _chargerUtilisateurConnecte();
  }


  Future<void> _chargerUtilisateurConnecte() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _currentUserModel = UserModel.fromFirestore(doc);
      });
      _verifierStatutEquipeUtilisateur();
    }
  }

  /// Vérifie si l'utilisateur est dans un duo en recherche et si un membre a un logement.
  /// Si oui, masque l'onglet "Avec logement".
  Future<void> _verifierStatutEquipeUtilisateur() async {
    final currentUserUid = _auth.currentUser?.uid;
    if (currentUserUid == null) return;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .where('rechercheColocActive', isEqualTo: true)
        .where('membres', arrayContains: currentUserUid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty || !mounted) return;

    final conversation = querySnapshot.docs.first;
    final membresIds = List<String>.from(conversation.data()['membres'] ?? []);
    final membresInfos = await _recupererInfosMembres(membresIds);

    final unMembreADejaLogement =
        membresInfos.values.any((info) => info?['aDejaUnLogement'] == true);

    if (unMembreADejaLogement && mounted) {
      setState(() {
        _peutVoirOngletAvecLogement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentUser = snapshot.data;

        if (currentUser == null) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Utilisateur non connecté',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          );
        }

        // Si le modèle utilisateur n'est pas encore chargé, on affiche un loader
        // et on s'assure que le chargement est en cours.
        if (_currentUserModel == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final theme = Theme.of(context);

        // Si l'utilisateur a déjà un logement : pas de sous-onglets, affiche uniquement les étudiants sans logement
        if (_currentUserModel?.aDejaUnLogement == true) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Découvrir',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFF1E3A5F),
            ),
            body: _buildStudentList(currentUser.uid, filtrerSansLogement: true),
          );
        }

        // Étudiant SANS logement : affiche les sous-onglets
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Découvrir',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF1E3A5F),
          ),
          body: Column(
            children: [
              // Sous-onglets
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _sousOngletActif = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _sousOngletActif == 0
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Sans logement',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _sousOngletActif == 0
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_peutVoirOngletAvecLogement)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _sousOngletActif = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _sousOngletActif == 1
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Avec logement',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _sousOngletActif == 1
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Liste des étudiants filtrée
              Expanded(
                child: _sousOngletActif == 0
                    ? _buildStudentList(currentUser.uid,
                        filtrerSansLogement: true)
                    : _buildStudentList(currentUser.uid,
                        filtrerAvecLogement: true),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Construit la liste des étudiants avec filtre optionnel sur le statut logement
  Widget _buildStudentList(
    String currentUserId, {
    bool? filtrerSansLogement,
    bool? filtrerAvecLogement,
  }) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _matchingService.getMatchedStudents(
          currentUserId,
          filtrerParStatutLogement: _sousOngletActif == 0 ? false : true,
        ),
        _recupererEquipesEnRecherche(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
 
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Erreur : ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
 
        // 1. Extraction des étudiants
        final rawStudents = (snapshot.data != null && snapshot.data!.isNotEmpty)
            ? snapshot.data![0]
            : [];
        final List<Map<String, dynamic>> students = (rawStudents is List)
            ? rawStudents.cast<Map<String, dynamic>>()
            : [];
 
        // 2. Extraction et filtrage des équipes (Duos)
        final rawTeams = (snapshot.data != null && snapshot.data!.length > 1)
            ? snapshot.data![1]
            : [];
        final List<QueryDocumentSnapshot> teams = (rawTeams is List)
            ? rawTeams.whereType<QueryDocumentSnapshot>().toList()
            : [];
 
        final List<QueryDocumentSnapshot> filteredTeams = teams.where((teamDoc) {
          final data = teamDoc.data() as Map<String, dynamic>?;
          final bool aUnLogement = data?['aUnLogement'] ?? data?['aDejaUnLogement'] ?? false;
 
          // Si onglet 0 (Sans logement = recherche logement), on montre les duos QUI ONT un logement
          // Si onglet 1 (Avec logement), on montre les duos SANS logement
          if (_sousOngletActif == 0) {
            return aUnLogement == true;
          } else {
            return aUnLogement == false;
          }
        }).toList();
 
        // 3. Combinaison des duos filtrés et des étudiants
        final combinedList = [...filteredTeams, ...students];
 
        if (combinedList.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                "Aucun profil ou duo disponible dans cette catégorie.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
 
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: combinedList.length,
            itemBuilder: (context, index) {
              final item = combinedList[index];
              if (item is QueryDocumentSnapshot) {
                return _buildCarteEquipe(item);
              } else if (item is Map<String, dynamic>) {
                return _buildStudentCard(item);
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
  // ---------------------------------------------------------------------------
  // Carte équipe
  // ---------------------------------------------------------------------------
  Widget _buildCarteEquipe(QueryDocumentSnapshot conversationDoc) {
    final theme = Theme.of(context);
    final conversationData = conversationDoc.data() as Map<String, dynamic>;
    final membresIds = List<String>.from(conversationData['membres'] ?? []);
    final quartier = conversationData['logementQuartier'] ?? 'Quartier non spécifié';
    final partCandidat =
        (conversationData['partFixeCandidat'] as num?)?.toInt() ?? 0;
    final textePart =
        partCandidat > 0 ? '${_formatBudget(partCandidat.toDouble())} FCFA/mois' : 'Loyer à discuter';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.teal.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.groups_rounded,
                          size: 16, color: Colors.teal.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Duo en recherche',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '1 place dispo',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, Map<String, dynamic>?>>(
              future: _recupererInfosMembres(membresIds),
              builder: (context, snapshot) {
                final membresInfos = snapshot.data ?? {};
                final noms = membresInfos.values
                    .map((info) => info?['prenom'] as String? ?? 'Membre')
                    .join(' & ');

                return Row(
                  children: [
                    // Avatars
                    SizedBox(
                      width: 68,
                      height: 40,
                      child: Stack(
                        children: [
                          if (membresInfos.length > 1)
                            Positioned(
                              left: 28,
                              child: _buildAvatar(
                                  membresInfos[membresIds.elementAt(1)]),
                            ),
                          if (membresInfos.isNotEmpty)
                            Positioned(
                              left: 0,
                              child: _buildAvatar(
                                  membresInfos[membresIds.elementAt(0)]),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Noms
                    Expanded(
                      child: Text(
                        noms.isEmpty ? 'Duo Mon Coloc' : noms,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FutureBuilder<int>(
                      future: _matchingService.calculerScoreMoyenEquipe(
                          _auth.currentUser!.uid, membresIds),
                      builder: (context, scoreSnapshot) {
                        final averageScore = scoreSnapshot.data ?? 0;
                        return _buildScoreBadge(averageScore);
                      },
                    )
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  _proposerCandidatureEquipe(conversationDoc);
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text("Proposer ma candidature"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Carte étudiant
  // ---------------------------------------------------------------------------
  Widget _buildStudentCard(Map<String, dynamic> studentData) {
    final theme = Theme.of(context);
    final score = studentData['scoreMatching'] as int? ?? 0;
    final prenom = studentData['prenom'] as String? ?? 'Inconnu';
    final ecole = studentData['ecoleUniversite'] as String? ?? '';
    final photoUrl = studentData['photoUrl'] as String?;
    final aDejaUnLogement = studentData['aDejaUnLogement'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Ligne supérieure : Avatar, infos, score ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? NetworkImage(photoUrl)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Text(
                          prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prenom,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      if (ecole.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.school_rounded,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                ecole,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Badge indiquant le statut logement
                      if (aDejaUnLogement) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.home_rounded,
                              size: 14,
                              color: Colors.green[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'A un logement',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Jauge de score
                _buildScoreBadge(score),
              ],
            ),

            // --- Badges d'habitudes partagées ---
            if (_currentUserModel != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildSharedHabitsChips(studentData),
              ),
            ],

            // --- Boutons d'action ---
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _voirProfil(studentData);
                    },
                    icon: const Icon(Icons.person_search_rounded, size: 18),
                    label: const Text('Voir le profil'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      _discuter(studentData);
                    },
                    icon: const Icon(Icons.handshake_rounded, size: 18),
                    label: const Text('Proposer une colocation'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Badge de score circulaire
  // ---------------------------------------------------------------------------
  Widget _buildScoreBadge(int score) {
    final Color couleur;
    final String label;
    if (score >= 80) {
      couleur = const Color(0xFF2E7D32); // vert foncé
      label = 'Excellent';
    } else if (score >= 60) {
      couleur = const Color(0xFF558B2F); // vert clair
      label = 'Très bon';
    } else if (score >= 40) {
      couleur = const Color(0xFFF9A825); // jaune/ambre
      label = 'Bon';
    } else if (score >= 20) {
      couleur = const Color(0xFFEF6C00); // orange
      label = 'Moyen';
    } else {
      couleur = const Color(0xFFC62828); // rouge
      label = 'Faible';
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: couleur.withOpacity(0.1),
        border: Border.all(color: couleur.withOpacity(0.4), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: couleur,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: couleur,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Chips d'habitudes partagées
  // ---------------------------------------------------------------------------
  List<Widget> _buildSharedHabitsChips(Map<String, dynamic> studentData) {
    final chips = <Widget>[];
    final current = _currentUserModel!;

    // 1. Même école
    if (current.ecoleUniversite.isNotEmpty &&
        (studentData['ecoleUniversite'] as String? ?? '').isNotEmpty &&
        current.ecoleUniversite.trim().toLowerCase() ==
            (studentData['ecoleUniversite'] as String).trim().toLowerCase()) {
      chips.add(
        _buildChip(
          icon: Icons.school_rounded,
          label: 'Même école',
          color: const Color(0xFF1565C0),
        ),
      );
    }

    // 2. Quartier partagé
    final currentQuartiers = current.quartierCible;
    final studentQuartiers = UserModel.safeStringList(
      studentData['quartierCible'],
    );
    final quartiersCommuns = currentQuartiers
        .where((q) => studentQuartiers.contains(q))
        .toList();
    if (quartiersCommuns.isNotEmpty) {
      for (final quartier in quartiersCommuns.take(2)) {
        chips.add(
          _buildChip(
            icon: Icons.location_on_rounded,
            label: quartier,
            color: const Color(0xFF7C3AED),
          ),
        );
      }
    }

    // 3. Non-fumeur partagé
    final currentFumeur = current.fumeur;
    final studentFumeur = studentData['fumeur'] as bool? ?? false;
    if (!currentFumeur && !studentFumeur) {
      chips.add(
        _buildChip(
          icon: Icons.smoke_free_rounded,
          label: 'Non-fumeur',
          color: const Color(0xFF2E7D32),
        ),
      );
    } else if (currentFumeur && studentFumeur) {
      chips.add(
        _buildChip(
          icon: Icons.smoking_rooms_rounded,
          label: 'Fumeur',
          color: const Color(0xFFE65100),
        ),
      );
    }

    // 4. Même besoin de silence
    if (current.besoinSilence ==
        (studentData['besoinSilence'] as bool? ?? false)) {
      if (current.besoinSilence) {
        chips.add(
          _buildChip(
            icon: Icons.volume_mute_rounded,
            label: 'Calme',
            color: const Color(0xFF0277BD),
          ),
        );
      }
    }

    // 5. Mixité acceptée
    if (current.accepteMixite ==
            (studentData['accepteMixite'] as bool? ?? false) &&
        current.accepteMixite) {
      chips.add(
        _buildChip(
          icon: Icons.people_rounded,
          label: 'Mixité acceptée',
          color: const Color(0xFF6A1B9A),
        ),
      );
    }

    // 6. Budget compatible
    final currentBudget = current.budgetMaxFCFA;
    final studentBudget =
        (studentData['budgetMaxFCFA'] as num?)?.toDouble() ?? 0;
    if (currentBudget > 0 && studentBudget > 0) {
      final diff = (currentBudget - studentBudget).abs();
      if (diff <= 20000) {
        chips.add(
          _buildChip(
            icon: Icons.attach_money_rounded,
            label: 'Budget ~ ${_formatBudget(currentBudget)}',
            color: const Color(0xFF00897B),
          ),
        );
      }
    }

    return chips;
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  void _voirProfil(Map<String, dynamic> studentData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(userData: studentData),
      ),
    );
  }

  void _discuter(Map<String, dynamic> studentData) {
    final uid = studentData['uid'] as String?;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de lancer la discussion : utilisateur invalide',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatScreen(destinataireId: uid)));
  }
  // ---------------------------------------------------------------------------
  // Helpers pour les équipes
  // ---------------------------------------------------------------------------
  
  /// Récupère les conversations où la recherche de coloc est active.
  Future<List<QueryDocumentSnapshot>> _recupererEquipesEnRecherche() async {
    final currentUserUid = _auth.currentUser?.uid;
    if (currentUserUid == null) return [];

     try {
       final querySnapshot = await FirebaseFirestore.instance
           .collection('conversations')
           .where('rechercheColocActive', isEqualTo: true)
           .get();
 
       // Filtrer les équipes :
       // 1. Doivent avoir moins de 3 membres (une place disponible).
       // 2. Exclure le propre duo de l'utilisateur.
       // 3. Exclure les duos auxquels l'utilisateur a déjà postulé.
       return querySnapshot.docs.where((doc) {
         final data = doc.data() as Map<String, dynamic>?;
         if (data == null) return false;
 
         final membres = List<String>.from(data['membres'] ?? []);
         final aUnePlace = membres.length < 3;
         if (!aUnePlace || membres.contains(currentUserUid)) {
           return false;
         }
 
         return true;
       }).toList();
     } catch (e) {
       debugPrint("Erreur ou restriction de droits sur 'conversations': $e");
       return []; // Retourne une liste vide au lieu de faire planter la page
     }
  }

  /// Récupère les infos de plusieurs utilisateurs avec un système de cache.
  Future<Map<String, Map<String, dynamic>?>> _recupererInfosMembres(
      List<String> uids) async {
    final result = <String, Map<String, dynamic>?>{};
    final uidsToFetch = <String>[];
    for (final uid in uids) {
      if (_userCache.containsKey(uid)) {
        result[uid] = _userCache[uid];
      } else {
        uidsToFetch.add(uid);
      }
    }
    if (uidsToFetch.isNotEmpty) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: uidsToFetch)
          .get();
      for (var doc in querySnapshot.docs) {
        _userCache[doc.id] = doc.data();
        result[doc.id] = doc.data();
      }
    }
    return result;
  }

  Widget _buildAvatar(Map<String, dynamic>? userInfo) {
    final photoUrl = userInfo?['photoUrl'] as String?;
    final prenom = userInfo?['prenom'] as String? ?? '?';
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.teal.shade100,
      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
          ? NetworkImage(photoUrl)
          : null,
      child: (photoUrl == null || photoUrl.isEmpty)
          ? Text(
              prenom[0].toUpperCase(),
              style: TextStyle(
                  color: Colors.teal.shade800, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }

  /// Affiche une modale pour que l'utilisateur postule à une équipe.
  void _proposerCandidatureEquipe(QueryDocumentSnapshot conversationDoc) {
    final conversationData = conversationDoc.data() as Map<String, dynamic>;
    final membresIds = List<String>.from(conversationData['membres'] ?? []);

    // Récupérer les infos pour l'affichage dans la modale
    _recupererInfosMembres(membresIds).then((membresInfos) {
      final noms = membresInfos.values
          .map((info) => info?['prenom'] as String? ?? 'Membre')
          .join(' & ');

      final partCandidat =
          (conversationData['partFixeCandidat'] as num?)?.toInt() ?? 0;
      final textePart = partCandidat > 0
          ? '$partCandidat FCFA / mois'
          : 'À discuter avec les membres';

      final messageController = TextEditingController();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rejoindre la colocation de $noms',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Votre part : $textePart',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message d\'introduction (facultatif)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      _envoyerCandidatureEquipe(
                          conversationDoc.id, messageController.text);
                      Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Confirmer et envoyer'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    });
  }

  /// Formate un budget en FCFA (ex: 150000 → "150k")
  String _formatBudget(double montant) {
    if (montant >= 1000000) {
      return '${(montant / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
    if (montant >= 1000) {
      return '${(montant / 1000).toStringAsFixed(0)}k';
    }
    return montant.toStringAsFixed(0);
  }

  /// Enregistre la candidature d'un utilisateur pour rejoindre une équipe.
  Future<void> _envoyerCandidatureEquipe(
      String conversationId, String message) async {
    final currentUserUid = _auth.currentUser?.uid;
    if (currentUserUid == null) return;

    try {
      final docRef =
          FirebaseFirestore.instance.collection('conversations').doc(conversationId);

      // On utilise set avec merge:true pour créer le champ 'candidatures' s'il n'existe pas
      await docRef.set({
        'candidatures': {
          currentUserUid: {
            'candidatId': currentUserUid,
            'message': message.trim(),
            'statut': 'en_attente',
            'date': FieldValue.serverTimestamp(),
          }
        }
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Candidature envoyée avec succès !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'envoi : $e')));
      }
    }
  }
}
