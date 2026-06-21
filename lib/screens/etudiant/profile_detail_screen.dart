import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:mon_coloc/screens/chat_screen.dart';
import 'package:mon_coloc/services/chat_service.dart';

/// Écran de profil détaillé d'un étudiant.
/// Accessible depuis l'onglet "Découvrir" en cliquant sur "Voir le profil".
class ProfileDetailScreen extends StatefulWidget {
  /// Données de l'étudiant ciblé (provenant du matching)
  final Map<String, dynamic> userData;

  const ProfileDetailScreen({super.key, required this.userData});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Données complètes de l'utilisateur (construites depuis le Map)
  late UserModel _user;

  /// Chargement en cours
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  void _initialiser() {
    try {
      // Construire un UserModel à partir des données du matching
      // (les champs sont déjà dans le Map retourné par matching_service)
      _user = UserModel(
        uid: widget.userData['uid'] as String? ?? '',
        email: widget.userData['email'] as String? ?? '',
        nom: widget.userData['nom'] as String? ?? '',
        prenom: widget.userData['prenom'] as String? ?? '',
        telephone: widget.userData['telephone'] as String? ?? '',
        ecoleUniversite: widget.userData['ecoleUniversite'] as String? ?? '',
        role: widget.userData['role'] as String? ?? 'etudiant',
        estVerifie: widget.userData['estVerifie'] as bool? ?? false,
        photoUrl: widget.userData['photoUrl'] as String?,
        filiere: widget.userData['filiere'] as String?,
        biographie: widget.userData['biographie'] as String?,
        justificatifUrl: widget.userData['justificatifUrl'] as String?,
        budgetMaxFCFA: (widget.userData['budgetMaxFCFA'] as num?)?.toDouble() ?? 0,
        quartierCible: UserModel.safeStringList(widget.userData['quartierCible']),
        statutLogement: StatutLogement.values.firstWhere(
          (e) => e.name == widget.userData['statutLogement'],
          orElse: () => StatutLogement.chercheUnLogement,
        ),
        sexe: Sexe.values.firstWhere(
          (e) => e.name == widget.userData['sexe'],
          orElse: () => Sexe.homme,
        ),
        accepteMixite: widget.userData['accepteMixite'] as bool? ?? false,
        zoneRecherche: widget.userData['zoneRecherche'] as String?,
        typeLogement: widget.userData['typeLogement'] as String?,
        proprete: Proprete.values.firstWhere(
          (e) => e.name == widget.userData['proprete'],
          orElse: () => Proprete.propre,
        ),
        rythmeDeVie: RythmeDeVie.values.firstWhere(
          (e) => e.name == widget.userData['rythmeDeVie'],
          orElse: () => RythmeDeVie.leveTot,
        ),
        fumeur: widget.userData['fumeur'] as bool? ?? false,
        statutAnimaux: StatutAnimaux.values.firstWhere(
          (e) => e.name == widget.userData['statutAnimaux'],
          orElse: () => StatutAnimaux.non,
        ),
        typeAnimaux: widget.userData['typeAnimaux'] as String?,
        bruitsFortsVolume: widget.userData['bruitsFortsVolume'] as bool? ?? false,
        appelsFrequents: widget.userData['appelsFrequents'] as bool? ?? false,
        soireesAmis: widget.userData['soireesAmis'] as bool? ?? false,
        besoinSilence: widget.userData['besoinSilence'] as bool? ?? false,
        horaireRevision: HoraireRevision.values.firstWhere(
          (e) => e.name == widget.userData['horaireRevision'],
          orElse: () => HoraireRevision.flexible,
        ),
        niveauSociabilite: widget.userData['niveauSociabilite'] as int?,
        dateInscription: widget.userData['dateInscription'] != null
            ? (widget.userData['dateInscription'] as Timestamp).toDate()
            : DateTime.now(),
      );

      if (mounted) {
        setState(() => _chargement = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _chargement = false);
      }
    }
  }

  /// Ouvre le chat avec cet étudiant (crée ou réutilise la conversation).
  Future<void> _ouvrirChat() async {
    final uid = _user.uid;
    if (uid.isEmpty) return;

    try {
      final conversationId =
          await _chatService.obtenirOuCreerConversation(uid);

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            destinataireId: uid,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_chargement) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Profil'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1E3A5F),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // --- En-tête (Header) ---
            _buildHeader(theme),

            const SizedBox(height: 8),

            // --- Section Habitudes de vie ---
            _buildSection(
              theme: theme,
              icon: Icons.auto_awesome_rounded,
              title: 'Habitudes de vie',
              child: _buildHabitsSection(theme),
            ),

            const SizedBox(height: 8),

            // --- Section À propos ---
            if (_user.biographie != null && _user.biographie!.isNotEmpty)
              _buildSection(
                theme: theme,
                icon: Icons.person_outline_rounded,
                title: 'À propos de moi',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _user.biographie!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF37474F),
                      height: 1.6,
                    ),
                  ),
                ),
              ),

            if (_user.biographie != null && _user.biographie!.isNotEmpty)
              const SizedBox(height: 8),

            // --- Section Critères de logement ---
            _buildSection(
              theme: theme,
              icon: Icons.home_work_rounded,
              title: 'Critères de logement recherché',
              child: _buildLogementCriteria(theme),
            ),

            const SizedBox(height: 100), // Espace pour le bottom bar
          ],
        ),
      ),

      // --- Bouton d'action fixé en bas ---
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  // ---------------------------------------------------------------------------
  // EN-TÊTE
  // ---------------------------------------------------------------------------
  Widget _buildHeader(ThemeData theme) {
    final prenom = _user.prenom;
    final nom = _user.nom;
    final age = _calculerAge(_user.dateInscription);
    final ecole = _user.ecoleUniversite;
    final filiere = _user.filiere;
    final photoUrl = _user.photoUrl;
    final estVerifie = _user.estVerifie;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(
                        prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),

              // Badge vérifié
              if (estVerifie)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Nom et âge
          Text(
            '$prenom $nom${age != null ? ', $age ans' : ''}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3A5F),
            ),
          ),

          const SizedBox(height: 8),

          // Badge école
          if (ecole.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_rounded,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    ecole,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

          // Filière
          if (filiere != null && filiere.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              filiere,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Badge vérifié (texte)
          if (estVerifie) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2E7D32).withOpacity(0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded,
                      size: 16, color: Color(0xFF2E7D32)),
                  SizedBox(width: 6),
                  Text(
                    'Profil Vérifié',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION GÉNÉRIQUE
  // ---------------------------------------------------------------------------
  Widget _buildSection({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HABITUDES DE VIE
  // ---------------------------------------------------------------------------
  Widget _buildHabitsSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          // Fumeur / Non-fumeur
          _buildHabitChip(
            icon: _user.fumeur ? Icons.smoking_rooms_rounded : Icons.smoke_free_rounded,
            label: _user.fumeur ? 'Fumeur' : 'Non-fumeur',
            color: _user.fumeur ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
          ),

          // Rythme de vie
          _buildHabitChip(
            icon: _user.rythmeDeVie == RythmeDeVie.leveTot
                ? Icons.wb_sunny_rounded
                : Icons.nightlight_round,
            label: _user.rythmeDeVie == RythmeDeVie.leveTot
                ? 'Lève-tôt'
                : 'Couche-tard',
            color: _user.rythmeDeVie == RythmeDeVie.leveTot
                ? const Color(0xFFF9A825)
                : const Color(0xFF5D4037),
          ),

          // Propreté
          _buildHabitChip(
            icon: Icons.cleaning_services_rounded,
            label: _labelProprete(_user.proprete),
            color: const Color(0xFF00897B),
          ),

          // Animaux
          _buildHabitChip(
            icon: _user.statutAnimaux == StatutAnimaux.non
                ? Icons.pets_rounded
                : Icons.pets_rounded,
            label: _labelAnimaux(_user.statutAnimaux),
            color: const Color(0xFF7C3AED),
          ),

          // Bruits / Volume
          _buildHabitChip(
            icon: _user.bruitsFortsVolume
                ? Icons.volume_up_rounded
                : Icons.volume_mute_rounded,
            label: _user.bruitsFortsVolume ? 'Bruits acceptés' : 'Calme',
            color: _user.bruitsFortsVolume
                ? const Color(0xFFE65100)
                : const Color(0xFF0277BD),
          ),

          // Soirées amis
          _buildHabitChip(
            icon: _user.soireesAmis
                ? Icons.celebration_rounded
                : Icons.nightlife_rounded,
            label: _user.soireesAmis ? 'Soirées entre amis' : 'Pas de soirées',
            color: _user.soireesAmis
                ? const Color(0xFF6A1B9A)
                : const Color(0xFF37474F),
          ),

          // Appels fréquents
          _buildHabitChip(
            icon: _user.appelsFrequents
                ? Icons.call_rounded
                : Icons.call_end_rounded,
            label: _user.appelsFrequents ? 'Appels fréquents' : 'Peu d\'appels',
            color: _user.appelsFrequents
                ? const Color(0xFF1565C0)
                : const Color(0xFF546E7A),
          ),

          // Besoin de silence
          if (_user.besoinSilence)
            _buildHabitChip(
              icon: Icons.hearing_disabled_rounded,
              label: 'Besoin de silence',
              color: const Color(0xFF37474F),
            ),

          // Horaire de révision
          _buildHabitChip(
            icon: Icons.menu_book_rounded,
            label: 'Révision : ${_labelHoraireRevision(_user.horaireRevision)}',
            color: const Color(0xFF1565C0),
          ),

          // Niveau de sociabilité
          if (_user.niveauSociabilite != null)
            _buildHabitChip(
              icon: Icons.people_rounded,
              label: 'Sociabilité : ${_user.niveauSociabilite}/5',
              color: const Color(0xFFE91E63),
            ),

          // Mixité
          _buildHabitChip(
            icon: _user.accepteMixite
                ? Icons.people_rounded
                : Icons.person_rounded,
            label: _user.accepteMixite ? 'Mixité acceptée' : 'Non-mixte',
            color: _user.accepteMixite
                ? const Color(0xFF6A1B9A)
                : const Color(0xFF37474F),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CRITÈRES DE LOGEMENT
  // ---------------------------------------------------------------------------
  Widget _buildLogementCriteria(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Budget max
          _buildCriteriaRow(
            icon: Icons.attach_money_rounded,
            label: 'Budget max',
            value: '${_formatBudget(_user.budgetMaxFCFA)} FCFA/mois',
            color: const Color(0xFF00897B),
          ),

          const SizedBox(height: 12),

          // Zone géographique
          _buildCriteriaRow(
            icon: Icons.location_on_rounded,
            label: 'Zone préférée',
            value: _user.quartierCible.isNotEmpty
                ? _user.quartierCible.join(', ')
                : 'Non spécifié',
            color: const Color(0xFF7C3AED),
          ),

          const SizedBox(height: 12),

          // Type de logement
          if (_user.typeLogement != null && _user.typeLogement!.isNotEmpty)
            _buildCriteriaRow(
              icon: Icons.home_rounded,
              label: 'Type de logement',
              value: _user.typeLogement!,
              color: const Color(0xFF1565C0),
            ),

          if (_user.typeLogement != null && _user.typeLogement!.isNotEmpty)
            const SizedBox(height: 12),

          // Statut logement
          _buildCriteriaRow(
            icon: Icons.search_rounded,
            label: 'Statut',
            value: _user.statutLogement == StatutLogement.chercheUnLogement
                ? 'Cherche un logement'
                : 'A déjà un logement',
            color: const Color(0xFFE65100),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM BAR
  // ---------------------------------------------------------------------------
  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _ouvrirChat,
            icon: const Icon(Icons.chat_rounded, size: 20),
            label: const Text(
              'Envoyer un message',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UTILITAIRES
  // ---------------------------------------------------------------------------

  /// Calcule l'âge approximatif à partir d'une date d'inscription.
  int? _calculerAge(DateTime dateInscription) {
    // On utilise la date d'inscription comme approximation
    // (l'âge réel n'est pas stocké dans le modèle)
    final now = DateTime.now();
    final age = now.year - dateInscription.year;
    if (now.month < dateInscription.month ||
        (now.month == dateInscription.month && now.day < dateInscription.day)) {
      return age - 1;
    }
    // On ajoute ~18 ans comme base (âge étudiant typique)
    return age >= 0 ? age + 18 : null;
  }

  String _labelProprete(Proprete p) {
    switch (p) {
      case Proprete.tresPropre:
        return 'Très propre';
      case Proprete.propre:
        return 'Propre';
      case Proprete.moyen:
        return 'Moyen';
    }
  }

  String _labelAnimaux(StatutAnimaux s) {
    switch (s) {
      case StatutAnimaux.non:
        return 'Pas d\'animaux';
      case StatutAnimaux.enAPossession:
        return 'A des animaux';
      case StatutAnimaux.tolere:
        return 'Animaux tolérés';
    }
  }

  String _labelHoraireRevision(HoraireRevision h) {
    switch (h) {
      case HoraireRevision.jour:
        return 'Jour';
      case HoraireRevision.nuit:
        return 'Nuit';
      case HoraireRevision.flexible:
        return 'Flexible';
    }
  }

  String _formatBudget(double montant) {
    if (montant >= 1000000) {
      return '${(montant / 1000000).toStringAsFixed(1)}M';
    }
    if (montant >= 1000) {
      return '${(montant / 1000).toStringAsFixed(0)} ${(montant % 1000).toStringAsFixed(0).padLeft(3, '0')}';
    }
    return montant.toStringAsFixed(0);
  }
}