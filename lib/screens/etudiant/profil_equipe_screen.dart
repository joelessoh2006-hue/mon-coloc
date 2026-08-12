import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:mon_coloc/screens/chat_screen.dart';
import 'package:mon_coloc/services/matching_service.dart';
import 'package:mon_coloc/services/user_service.dart';

/// Écran affichant le profil détaillé d'une équipe (duo ou plus).
///
/// Permet à un étudiant de consulter les informations sur une équipe
/// avant de décider de postuler pour la rejoindre.
class ProfilEquipeScreen extends StatefulWidget {
  /// L'ID de la conversation qui représente l'équipe.
  final String conversationId;

  const ProfilEquipeScreen({super.key, required this.conversationId});

  @override
  State<ProfilEquipeScreen> createState() => _ProfilEquipeScreenState();
}

class _ProfilEquipeScreenState extends State<ProfilEquipeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final MatchingService _matchingService = MatchingService();

  /// Cache pour les informations des membres.
  final Map<String, UserModel> _membresCache = {};

  /// Récupère les informations d'un membre avec mise en cache.
  Future<UserModel?> _recupererMembre(String uid) async {
    if (_membresCache.containsKey(uid)) {
      return _membresCache[uid];
    }
    final user = await _userService.recupererUtilisateur(uid);
    if (user != null) {
      _membresCache[uid] = user;
    }
    return user;
  }

  /// Récupère les informations de tous les membres de l'équipe.
  Future<List<UserModel>> _recupererInfosMembres(List<String> uids) async {
    final List<UserModel> membres = [];
    for (final uid in uids) {
      final membre = await _recupererMembre(uid);
      if (membre != null) {
        membres.add(membre);
      }
    }
    return membres;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text("Cette équipe n'existe plus.")),
          );
        }

        final equipeData = snapshot.data!.data() as Map<String, dynamic>;
        final membresIds = List<String>.from(equipeData['membres'] ?? []);
        final candidatures =
            equipeData['candidatures'] as Map<String, dynamic>? ?? {};
        final monUid = _auth.currentUser?.uid;
        final estMembre = monUid != null && membresIds.contains(monUid);
        final aDejaPostule = monUid != null && candidatures.containsKey(monUid);

        return Scaffold(
          body: _buildContenuPrincipal(context, equipeData, membresIds),
          bottomNavigationBar:
              (!aDejaPostule && !estMembre)
                  ? _buildBarreCandidature(context)
                  : null,
        );
      },
    );
  }

  Widget _buildContenuPrincipal(
    BuildContext context,
    Map<String, dynamic> equipeData,
    List<String> membresIds,
  ) {
    return FutureBuilder<List<UserModel>>(
      future: _recupererInfosMembres(membresIds),
      builder: (context, membresSnapshot) {
        final membres = membresSnapshot.data ?? [];
        final noms = membres.map((m) => m.prenom).join(' & ');

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 250.0,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  noms.isNotEmpty ? 'Équipe de $noms' : 'Profil de l\'équipe',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: _buildEnTete(context, equipeData, membres),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionMembres(context, membres),
                      const SizedBox(height: 24),
                      _buildSectionProjetLogement(context, equipeData, membres),
                      const SizedBox(height: 24),
                      _buildSectionHabitudes(context, membres),
                      const SizedBox(height: 80), // Espace pour la barre du bas
                    ],
                  ),
                ),
              ]),
            ),
          ],
        );
      },
    );
  }

  /// En-tête avec avatars, score de match et places disponibles.
  Widget _buildEnTete(
    BuildContext context,
    Map<String, dynamic> equipeData,
    List<UserModel> membres,
  ) {
    final theme = Theme.of(context);
    final monUid = _auth.currentUser!.uid;
    final membresIds = membres.map((m) => m.uid).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond dégradé
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.6),
                theme.colorScheme.primary.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Contenu
        Padding(
          padding: const EdgeInsets.only(bottom: 48.0, left: 16, right: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Avatars superposés
                  SizedBox(
                    width: 100,
                    height: 50,
                    child: Stack(
                      children: List.generate(membres.length, (index) {
                        final membre = membres[index];
                        return Positioned(
                          left: index * 30.0,
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 23,
                              backgroundImage: membre.photoUrl != null
                                  ? NetworkImage(membre.photoUrl!)
                                  : null,
                              child: membre.photoUrl == null
                                  ? Text(membre.prenom[0])
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Score de match et places
                  Row(
                    children: [
                      _buildInfoChip(
                        icon: Icons.pie_chart_rounded,
                        label: FutureBuilder<int>(
                          future: _matchingService.calculerScoreMoyenEquipe(
                            monUid,
                            membresIds,
                          ),
                          builder: (context, snapshot) {
                            return Text(
                              '${snapshot.data ?? '...'}% Match',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        color: Colors.black.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        icon: Icons.person_add_alt_1_rounded,
                        label: const Text(
                          '1 place dispo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required Widget label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          label,
        ],
      ),
    );
  }

  /// Section listant les membres de l'équipe.
  Widget _buildSectionMembres(BuildContext context, List<UserModel> membres) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Membres de l\'équipe (${membres.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...membres.map(
          (membre) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: membre.photoUrl != null
                    ? NetworkImage(membre.photoUrl!)
                    : null,
                child: membre.photoUrl == null ? Text(membre.prenom[0]) : null,
              ),
              title: Text(
                '${membre.prenom} ${membre.nom}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(membre.filiere ?? 'Filière non spécifiée'),
            ),
          ),
        ),
      ],
    );
  }

  /// Section décrivant le projet logement de l'équipe.
  Widget _buildSectionProjetLogement(
    BuildContext context,
    Map<String, dynamic> equipeData,
    List<UserModel> membres,
  ) {
    final aUnLogement = membres.any((m) => m.aDejaUnLogement == true);
    final quartier = equipeData['logementQuartier'] as String?;
    final partCandidat = (equipeData['partFixeCandidat'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Projet Logement', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  aUnLogement ? Icons.home_work_rounded : Icons.search_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aUnLogement
                            ? 'Logement déjà trouvé !'
                            : 'Recherche en cours',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (aUnLogement && quartier != null)
                        Text('Quartier : $quartier'),
                      if (partCandidat > 0)
                        Text('Votre part : $partCandidat FCFA / mois'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Section affichant les habitudes de vie communes.
  Widget _buildSectionHabitudes(BuildContext context, List<UserModel> membres) {
    if (membres.isEmpty) return const SizedBox.shrink();
    // On prend le premier membre comme référence pour les habitudes communes
    final ref = membres.first;
    final tousNonFumeurs = membres.every((m) => !m.fumeur);
    final tousCalmes = membres.every((m) => m.besoinSilence);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Habitudes & Bio', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (tousNonFumeurs)
              const Chip(
                avatar: Icon(Icons.smoke_free),
                label: Text('Non-fumeurs'),
              ),
            if (tousCalmes)
              const Chip(avatar: Icon(Icons.volume_mute), label: Text('Calme')),
            Chip(
              avatar: const Icon(Icons.cleaning_services),
              label: Text('Propreté : ${ref.proprete.name}'),
            ),
            if (ref.accepteMixite)
              const Chip(avatar: Icon(Icons.people), label: Text('Mixité OK')),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          "Présentation de l'équipe :",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          ref.biographie ?? "Ce duo n'a pas encore rédigé de présentation.",
          style: TextStyle(color: Colors.grey.shade700, height: 1.5),
        ),
      ],
    );
  }

  /// Barre de navigation inférieure avec le bouton pour postuler.
  Widget _buildBarreCandidature(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: _proposerCandidature,
        icon: const Icon(Icons.send_rounded),
        label: const Text('Proposer ma candidature'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Logique pour envoyer la candidature.
  void _proposerCandidature() {
    final monUid = _auth.currentUser?.uid;
    if (monUid == null) return;

    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
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
              'Envoyer votre candidature',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message de motivation (facultatif)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  try {
                    await _firestore
                        .collection('conversations')
                        .doc(widget.conversationId)
                        .update({
                          'candidatures.$monUid': {
                            'candidatId': monUid,
                            'message': messageController.text.trim(),
                            'statut': 'en_attente',
                            'date': FieldValue.serverTimestamp(),
                          },
                        });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Candidature envoyée !'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur : $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Confirmer et Envoyer'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
