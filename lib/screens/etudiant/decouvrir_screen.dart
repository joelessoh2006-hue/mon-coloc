import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:mon_coloc/services/matching_service.dart';

/// Écran "Découvrir" — Affiche les profils étudiants triés par score de matching.
class DecouvrirScreen extends StatefulWidget {
  const DecouvrirScreen({super.key});

  @override
  State<DecouvrirScreen> createState() => _DecouvrirScreenState();
}

class _DecouvrirScreenState extends State<DecouvrirScreen> {
  final MatchingService _matchingService = MatchingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Utilisateur connecté (pour comparer les habitudes avec chaque profil)
  UserModel? _currentUserModel;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Utilisateur non connecté',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _matchingService.getMatchedStudents(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Recherche de colocataires...',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Erreur : ${snapshot.error}',
                style: const TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final students = snapshot.data ?? [];

        if (students.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 24),
                  const Text(
                    'Aucun profil étudiant vérifié n\'est disponible pour le moment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); // Déclenche un rebuild du FutureBuilder
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: students.length,
            itemBuilder: (context, index) {
              return _buildStudentCard(students[index]);
            },
          ),
        );
      },
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
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  child: Text(
                    prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
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
                            Icon(Icons.school_rounded,
                                size: 16, color: Colors.grey[500]),
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
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('Discuter'),
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
      chips.add(_buildChip(
        icon: Icons.school_rounded,
        label: 'Même école',
        color: const Color(0xFF1565C0),
      ));
    }

    // 2. Quartier partagé
    final currentQuartiers = current.quartierCible;
    final studentQuartiers = UserModel.safeStringList(studentData['quartierCible']);
    final quartiersCommuns =
        currentQuartiers.where((q) => studentQuartiers.contains(q)).toList();
    if (quartiersCommuns.isNotEmpty) {
      for (final quartier in quartiersCommuns.take(2)) {
        chips.add(_buildChip(
          icon: Icons.location_on_rounded,
          label: quartier,
          color: const Color(0xFF7C3AED),
        ));
      }
    }

    // 3. Non-fumeur partagé
    final currentFumeur = current.fumeur;
    final studentFumeur = studentData['fumeur'] as bool? ?? false;
    if (!currentFumeur && !studentFumeur) {
      chips.add(_buildChip(
        icon: Icons.smoke_free_rounded,
        label: 'Non-fumeur',
        color: const Color(0xFF2E7D32),
      ));
    } else if (currentFumeur && studentFumeur) {
      chips.add(_buildChip(
        icon: Icons.smoking_rooms_rounded,
        label: 'Fumeur',
        color: const Color(0xFFE65100),
      ));
    }

    // 4. Même besoin de silence
    if (current.besoinSilence ==
        (studentData['besoinSilence'] as bool? ?? false)) {
      if (current.besoinSilence) {
        chips.add(_buildChip(
          icon: Icons.volume_mute_rounded,
          label: 'Calme',
          color: const Color(0xFF0277BD),
        ));
      }
    }

    // 5. Mixité acceptée
    if (current.accepteMixite ==
            (studentData['accepteMixite'] as bool? ?? false) &&
        current.accepteMixite) {
      chips.add(_buildChip(
        icon: Icons.people_rounded,
        label: 'Mixité acceptée',
        color: const Color(0xFF6A1B9A),
      ));
    }

    // 6. Budget compatible
    final currentBudget = current.budgetMaxFCFA;
    final studentBudget =
        (studentData['budgetMaxFCFA'] as num?)?.toDouble() ?? 0;
    if (currentBudget > 0 && studentBudget > 0) {
      final diff = (currentBudget - studentBudget).abs();
      if (diff <= 20000) {
        chips.add(_buildChip(
          icon: Icons.attach_money_rounded,
          label: 'Budget ~ ${_formatBudget(currentBudget)}',
          color: const Color(0xFF00897B),
        ));
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profil de ${studentData['prenom']} — à implémenter'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _discuter(Map<String, dynamic> studentData) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chat avec ${studentData['prenom']} — à implémenter'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Formate un budget en FCFA (ex: 150000 → "150k")
  String _formatBudget(double montant) {
    if (montant >= 1000) {
      return '${(montant / 1000).toStringAsFixed(0)}k';
    }
    return montant.toStringAsFixed(0);
  }
}