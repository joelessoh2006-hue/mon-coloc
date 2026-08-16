import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/screens/chat_screen.dart';
import 'package:mon_coloc/screens/etudiant/profile_detail_screen.dart';
import 'package:mon_coloc/services/user_service.dart';
import 'package:mon_coloc/services/chat_service.dart';
import 'package:mon_coloc/services/matching_service.dart';
import 'package:mon_coloc/services/equipe_service.dart';

/// Écran "Mon Équipe" — Gestion de la colocation étudiante.
///
/// Affiche selon l'état de l'utilisateur :
/// 1. Sans binôme : message "Vous n'avez pas encore de binôme."
///    + requêtes de colocation reçues en attente (si existantes).
/// 2. Avec binôme validé : badge "Votre binôme est validé !" +
///    liste des membres de l'équipe + accès au chat privé.
///
/// Les discussions générales sont gérées exclusivement dans l'onglet
/// "Messagerie & Visites".
class MonEquipeScreen extends StatefulWidget {
  const MonEquipeScreen({super.key});

  @override
  State<MonEquipeScreen> createState() => _MonEquipeScreenState();
}

class _MonEquipeScreenState extends State<MonEquipeScreen> {
  final ChatService _chatService = ChatService();
  final EquipeService _equipeService = EquipeService();
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MatchingService _matchingService = MatchingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cache des infos utilisateur (uid -> Map)
  final Map<String, Map<String, dynamic>?> _cacheInfos = {};

  @override
  void initState() {
    super.initState();
  }

  /// Récupère les infos d'un utilisateur depuis Firestore (avec cache).
  Future<Map<String, dynamic>?> _recupererInfosUtilisateur(String uid) async {
    if (_cacheInfos.containsKey(uid)) return _cacheInfos[uid];

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      _cacheInfos[uid] = data;
      return data;
    } catch (_) {
      _cacheInfos[uid] = null;
      return null;
    }
  }

  /// Récupère les infos de plusieurs utilisateurs en une fois (avec cache).
  Future<Map<String, Map<String, dynamic>?>>
  _recupererInfosMultiplesUtilisateurs(List<String> uids) async {
    final result = <String, Map<String, dynamic>?>{};
    final uidsToFetch = <String>[];

    for (final uid in uids) {
      if (_cacheInfos.containsKey(uid)) {
        result[uid] = _cacheInfos[uid];
      } else {
        uidsToFetch.add(uid);
      }
    }

    if (uidsToFetch.isNotEmpty) {
      final fetched = await _equipeService.recupererInfosMembres(uidsToFetch);
      for (final entry in fetched.entries) {
        _cacheInfos[entry.key] = entry.value;
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text(
          'Utilisateur non connecté',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.ecouterConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Chargement de votre équipe…',
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur de chargement : ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }

        final conversationsBrutes = snapshot.data?.docs ?? [];

        // Séparer les conversations acceptées (binôme validé) des autres
        final conversationAcceptee = conversationsBrutes
            .cast<QueryDocumentSnapshot?>()
            .firstWhere((doc) {
              if (doc == null) return false;
              final data = doc.data() as Map<String, dynamic>;
              return data['demandeStatut'] == 'accepte';
            }, orElse: () => null);

        // Filtrer les demandes reçues en attente (proposées PAR un autre étudiant)
        final demandesRecues = conversationsBrutes.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final statut = data['demandeStatut'] as String?;
          final proposePar = data['proposePar'] as String?;
          return statut == 'en_attente' && proposePar != currentUser.uid;
        }).toList();

        return _buildVueComplete(
          currentUser,
          conversationAcceptee,
          demandesRecues,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // VUE COMPLÈTE
  // ---------------------------------------------------------------------------

  /// Construit la vue scrollable :
  /// - Si binôme validé : Section Équipe + Demandes reçues (si existantes)
  /// - Sinon : Message "Pas de binôme" + Demandes reçues (si existantes)
  Widget _buildVueComplete(
    User currentUser,
    QueryDocumentSnapshot? conversationAcceptee,
    List<QueryDocumentSnapshot> demandesRecues,
  ) {
    final String currentUserId = currentUser.uid;
    final bool aBinome = conversationAcceptee != null;

    return RefreshIndicator(
      onRefresh: () async {
        _cacheInfos.clear(); // Vider le cache pour rafraîchir les données
        setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // ================================================================
          // ÉTAT AVEC BINÔME VALIDÉ
          // ================================================================
          if (aBinome)
            _buildEspaceEquipeOfficielle(currentUser, conversationAcceptee),

          if (aBinome && demandesRecues.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 8),
              child: Divider(height: 1, thickness: 1),
            ),

          // ================================================================
          // DEMANDES DE COLOCATION REÇUES EN ATTENTE
          // ================================================================
          if (demandesRecues.isNotEmpty) ...[
            // Header différent selon qu'on a un binôme ou non
            _buildSectionHeader(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Demandes reçues',
              subtitle: aBinome
                  ? 'Ces étudiants veulent rejoindre votre équipe'
                  : 'Ces étudiants veulent former une équipe avec vous',
            ),
            const SizedBox(height: 8),
            ...demandesRecues.map(
              (doc) => _buildDemandeRecueCard(currentUser, doc),
            ),
          ],

          // ================================================================
          // MES CANDIDATURES ENVOYÉES (si pas de binôme)
          // ================================================================
          if (!aBinome)
            _buildMesCandidaturesSection(currentUserId),


          // ================================================================
          // ÉTAT SANS BINÔME ET SANS DEMANDE
          // ================================================================
          if (!aBinome && demandesRecues.isEmpty) _buildEmptyState(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ESPACE ÉQUIPE OFFICIELLE (avec binôme validé)
  // ---------------------------------------------------------------------------

  /// Construit l'espace "Équipe Officielle" avec les félicitations,
  /// la liste de TOUS les membres de l'équipe et le bouton d'accès au chat.
  Widget _buildEspaceEquipeOfficielle(
    User currentUser,
    DocumentSnapshot conversationDoc,
  ) {
    final data = conversationDoc.data() as Map<String, dynamic>;
    final equipeId = data['idEquipe'] as String?;

    // Si on a un idEquipe, on écoute l'équipe en temps réel pour avoir
    // la liste complète et à jour des membres
    if (equipeId != null && equipeId.isNotEmpty) {
      return _buildEquipeAvecStream(currentUser, conversationDoc, equipeId);
    }

    // Fallback : afficher uniquement les membres de la conversation (2 personnes)
    return _buildEquipeFromConversation(currentUser, conversationDoc);
  }

  /// Construit l'espace équipe en écoutant le document equipes en temps réel.
  Widget _buildEquipeAvecStream(
    User currentUser,
    DocumentSnapshot conversationDoc,
    String equipeId,
  ) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _equipeService.ecouterEquipe(equipeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // En attendant, afficher la version basée sur la conversation
          return _buildEquipeFromConversation(currentUser, conversationDoc);
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return _buildEquipeFromConversation(currentUser, conversationDoc);
        }

        final equipeData = snapshot.data!.data() as Map<String, dynamic>;
        final membres = List<String>.from(equipeData['membres'] as List? ?? []);
        final conversationId = conversationDoc.id;

        return _buildEquipeContent(currentUser, membres, conversationId);
      },
    );
  }

  /// Version fallback basée sur les membres de la conversation (2 personnes).
  Widget _buildEquipeFromConversation(
    User currentUser,
    DocumentSnapshot conversationDoc,
  ) {
    final data = conversationDoc.data() as Map<String, dynamic>;
    final membres = List<String>.from(data['membres'] as List);
    final conversationId = conversationDoc.id;

    return _buildEquipeContent(currentUser, membres, conversationId);
  }

  /// Construit le contenu de l'équipe avec la liste des membres.
  Widget _buildEquipeContent(
    User currentUser,
    List<String> membres,
    String conversationId,
  ) {
    // Filtrer pour ne garder que les autres membres (pas l'utilisateur connecté)
    final autresMembres = membres.where((id) => id != currentUser.uid).toList();

    return FutureBuilder<Map<String, Map<String, dynamic>?>>(
      future: _recupererInfosMultiplesUtilisateurs(membres),
      builder: (context, snapshot) {
        final infosMap = snapshot.data ?? {};

        // Infos de l'utilisateur connecté
        final currentUserInfos = infosMap[currentUser.uid];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Bannière de confirmation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    autresMembres.length == 1
                        ? 'Votre binôme est validé ! 🤝'
                        : 'Votre équipe est constituée ! 🏠',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vous êtes ${membres.length} membres dans cette colocation.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E7D32),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // --- NOUVEAU : Widget de sondage pour la recherche de coloc ---
            // S'affiche uniquement pour un binôme (2 membres)
            if (membres.length == 2) ...[
              const SizedBox(height: 24),
              SondageColocWidget(
                conversationId: conversationId,
                membres: membres,
              ), // Ajout de la virgule
            ],
            const SizedBox(height: 24),
            _CandidaturesRecuesWidget(
              conversationId: conversationId,
              membres: membres,
            ),

            // ], // Parenthèse fermante déplacée
            const SizedBox(height: 24),

            // Section : Membres de l'équipe
            Row(
              children: [
                const Icon(
                  Icons.group_rounded,
                  size: 20,
                  color: Color(0xFF1E3A5F),
                ),
                const SizedBox(width: 8),
                Text(
                  'Mon Équipe (${membres.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Carte de l'utilisateur connecté (en premier)
            _buildMembreCard(
              uid: currentUser.uid,
              infos: currentUserInfos,
              estMoi: true,
            ),
            const SizedBox(height: 8),

            // Cartes des autres membres
            ...autresMembres.map(
              (uid) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMembreCard(
                  uid: uid,
                  infos: infosMap[uid],
                  estMoi: false,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Bouton : Discussion privée
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  // Ouvrir le chat avec le premier autre membre (ou le seul)
                  if (autresMembres.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: conversationId,
                          destinataireId: autresMembres.first,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.chat_rounded, size: 20),
                label: Text(
                  autresMembres.length == 1
                      ? 'Ouvrir votre chat privé'
                      : 'Discuter avec l\'équipe',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            // Légende
            const SizedBox(height: 8),
            Center(
              child: Text(
                autresMembres.length == 1
                    ? 'Discutez avec votre colocataire officiel'
                    : 'Discutez avec les membres de votre équipe',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Construit une carte pour un membre de l'équipe.
  Widget _buildMembreCard({
    required String uid,
    required Map<String, dynamic>? infos,
    required bool estMoi,
  }) {
    final prenom = infos?['prenom'] as String? ?? 'Inconnu';
    final nom = infos?['nom'] as String? ?? '';
    final photoUrl = infos?['photoUrl'] as String?;
    final ecole = infos?['ecoleUniversite'] as String? ?? '';
    final filiere = infos?['filiere'] as String? ?? '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: estMoi
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.15),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        estMoi ? '$prenom $nom (Moi)' : '$prenom $nom',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      if (estMoi) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Vous',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (ecole.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.school_rounded,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            ecole,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (filiere.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      filiere,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION HEADER
  // ---------------------------------------------------------------------------

  /// Construit l'en-tête d'une section.
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
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
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit l'état vide quand l'utilisateur n'a pas de binôme
  /// et aucune demande en attente.
  Widget _buildEmptyState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            const Text(
              'Vous n\'avez pas encore de binôme.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Explorez les profils dans l\'onglet Découvrir'
                '\npour trouver votre futur colocataire !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CARTE DEMANDE REÇUE
  // ---------------------------------------------------------------------------

  /// Construit une carte pour une demande de colocation reçue.
  Widget _buildDemandeRecueCard(User currentUser, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final conversationId = doc.id;
    final proposePar = data['proposePar'] as String? ?? '';

    // L'expéditeur est le proposePar
    return FutureBuilder<Map<String, dynamic>?>(
      future: _recupererInfosUtilisateur(proposePar),
      builder: (context, snapshot) {
        final infos = snapshot.data;
        final prenom = infos?['prenom'] as String? ?? 'Inconnu';
        final nom = infos?['nom'] as String? ?? '';
        final photoUrl = infos?['photoUrl'] as String?;
        final ecole = infos?['ecoleUniversite'] as String? ?? '';
        final estVerifie = infos?['estVerifie'] as bool? ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.15),
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    // Infos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$prenom $nom',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          if (ecole.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              ecole,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          // Badge de statut de vérification
                          _buildVerificationBadge(estVerifie),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _voirProfil(infos!),
                        icon: const Icon(Icons.person_search_rounded, size: 18),
                        label: const Text('Voir le profil'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _ouvrirChat(conversationId, proposePar),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: const Text('Répondre'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerificationBadge(bool estVerifie) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: estVerifie
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            estVerifie ? Icons.verified_rounded : Icons.hourglass_top_rounded,
            size: 12,
            color: estVerifie ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            estVerifie ? 'Profil vérifié' : 'Non vérifié',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: estVerifie
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION MES CANDIDATURES
  // ---------------------------------------------------------------------------

  /// Construit la section affichant les candidatures envoyées par l'utilisateur.
  Widget _buildMesCandidaturesSection(String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('candidatures.$currentUserId.statut', isEqualTo: 'en_attente')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // Ne rien afficher si pas de candidatures
        }

        final candidatures = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 24),
            _buildSectionHeader(
              icon: Icons.outgoing_mail,
              title: 'Mes candidatures envoyées',
              subtitle: 'Suivez le statut de vos propositions de colocation',
            ),
            const SizedBox(height: 12),
            ...candidatures.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final candidatureData =
                  data['candidatures'][currentUserId] as Map<String, dynamic>;
              return _buildCandidatureEnvoyeeCard(
                  doc.id, candidatureData, data);
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  /// Construit une carte pour une candidature envoyée.
  Widget _buildCandidatureEnvoyeeCard(String conversationId,
      Map<String, dynamic> candidatureData, Map<String, dynamic> convData) {
    final membresEquipe = List<String>.from(convData['membres'] ?? []);
    final date = (candidatureData['date'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<Map<String, Map<String, dynamic>?>>(
              future: _recupererInfosMultiplesUtilisateurs(membresEquipe),
              builder: (context, snapshot) {
                final noms = snapshot.data?.values
                        .map((info) => info?['prenom'] as String? ?? 'Membre')
                        .join(' & ') ??
                    'Équipe';
                return Text(
                  'Équipe de $noms',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A5F),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Chip(
                  label: Text('En attente',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.orange,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                ),
                const Spacer(),
                if (date != null)
                  Text(
                    'Envoyée le ${date.day}/${date.month}/${date.year}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _annulerCandidature(conversationId, _auth.currentUser!.uid);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Candidature annulée.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Annuler la candidature'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Annule une candidature en mettant à jour son statut dans Firestore.
  Future<void> _annulerCandidature(
      String conversationId, String userId) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({'candidatures.$userId.statut': 'annulee'});
    } catch (e) {
      debugPrint("Erreur lors de l'annulation de la candidature: $e");
      // Optionnel : afficher un message d'erreur à l'utilisateur
    }
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  /// Ouvre l'écran de chat pour une conversation donnée.
  void _ouvrirChat(String conversationId, String destinataireId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          destinataireId: destinataireId,
        ),
      ),
    );
  }

  /// Ouvre l'écran de détail du profil.
  void _voirProfil(Map<String, dynamic> userData) {
    // On s'assure que l'UID est bien dans les données pour la navigation
    if (!userData.containsKey('uid')) {
      final entry = _cacheInfos.entries.firstWhere(
        (e) => e.value == userData,
        orElse: () => const MapEntry('', null),
      );
      if (entry.key.isNotEmpty) {
        userData['uid'] = entry.key;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(userData: userData),
      ),
    );
  }
}

/// Widget pour afficher et gérer les candidatures reçues.
class _CandidaturesRecuesWidget extends StatelessWidget {
  final String conversationId;
  final List<String> membres;
  MatchingService get _matchingService => MatchingService();

  const _CandidaturesRecuesWidget({
    required this.conversationId,
    required this.membres,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final allCandidatures =
            data['candidatures'] as Map<String, dynamic>? ?? {};

        final candidaturesEnAttente = allCandidatures.entries
            .where((e) => e.value['statut'] == 'en_attente')
            .toList();

        if (candidaturesEnAttente.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 32),
            const Text(
              'Candidatures reçues',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 12),
            ...candidaturesEnAttente.map(
              (c) => _buildCandidatCard(context, c.key, c.value),
            ),
          ],
        );
      },
    );
  }

  /// Ouvre l'écran de détail du profil pour un candidat.
  void _voirProfilCandidat(BuildContext context, String candidatId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(candidatId).get();
      if (doc.exists && context.mounted) {
        final userData = doc.data()!;
        userData['uid'] = candidatId; // Assurer que l'UID est présent
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfileDetailScreen(userData: userData)),
        );
      }
    } catch (e) {
      // Gérer l'erreur si nécessaire
    }
  }
  Widget _buildCandidatCard(
    BuildContext context,
    String candidatId,
    Map<String, dynamic> data,
  ) {
    final message = data['message'] as String? ?? 'Aucun message.';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.teal.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(candidatId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const LinearProgressIndicator();
                }
                final candidatData =
                    snapshot.data!.data() as Map<String, dynamic>;
                final prenom = candidatData['prenom'] as String? ?? 'Candidat';
                final photoUrl = candidatData['photoUrl'] as String?;

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null ? Text(prenom[0]) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        prenom,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    FutureBuilder<int>(
                      future: _matchingService.calculerScoreDetaille(
                          FirebaseAuth.instance.currentUser!.uid, candidatId),
                      builder: (context, scoreSnapshot) {
                        final score = scoreSnapshot.data ?? 0;
                        return Text(
                          'Match: $score%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      },
                    )
                  ],
                );
              },
            ),
            const Divider(height: 24),
            Text(
              'Message de motivation :',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(message.isNotEmpty ? '"$message"' : 'Aucun message.'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _voirProfilCandidat(context, candidatId),
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: const Text('Voir le profil du candidat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _gererCandidature(context, candidatId, false),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Refuser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        _gererCandidature(context, candidatId, true),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Accepter'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
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

  Future<void> _gererCandidature(
    BuildContext context,
    String candidatId,
    bool accepter,
  ) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId);

      if (accepter) {
        // 1. Ajouter le membre à la conversation
        await docRef.update({
          'membres': FieldValue.arrayUnion([candidatId]),
          'candidatures.$candidatId.statut': 'accepte',
        });

        // 2. Mettre à jour le profil du candidat
        await FirebaseFirestore.instance
            .collection('users')
            .doc(candidatId)
            .update({'aUneEquipe': true}); // Champ simple pour le moment
      } else {
        // Refuser
        await docRef.update({'candidatures.$candidatId.statut': 'refuse'});
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Candidature ${accepter ? 'acceptée' : 'refusée'} avec succès.',
            ),
            backgroundColor: accepter ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

/// Widget pour gérer le sondage de recherche de colocataires.
class SondageColocWidget extends StatefulWidget {
  final String conversationId;
  final List<String> membres;

  const SondageColocWidget({
    super.key,
    required this.conversationId,
    required this.membres,
  });

  @override
  State<SondageColocWidget> createState() => _SondageColocWidgetState();
}

class _SondageColocWidgetState extends State<SondageColocWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _voteEnCours = false;
  bool _relanceEnCours = false;

  Future<void> _voter(String vote) async {
    if (_voteEnCours) return;
    setState(() => _voteEnCours = true);

    try {
      final docRef = _firestore
          .collection('conversations')
          .doc(widget.conversationId);
      await docRef.update({'sondageRecherche.votes.$_currentUid': vote});

      // Après le vote, vérifier si tout le monde a voté pour traiter le résultat
      final doc = await docRef.get();
      final data = doc.data();
      if (data != null) {
        await _traiterResultatSondage(docRef, data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur lors du vote: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _voteEnCours = false);
      }
    }
  }

  Future<void> _traiterResultatSondage(
    DocumentReference docRef,
    Map<String, dynamic> data,
  ) async {
    final sondageData = data['sondageRecherche'] as Map<String, dynamic>? ?? {};
    final votes = sondageData['votes'] as Map<String, dynamic>? ?? {};

    if (votes.keys.length == 2) {
      // Tout le monde a voté
      final tousOui = votes.values.every((vote) => vote == 'oui');

      if (tousOui) {
        await docRef.update({
          'rechercheColocActive': true,
          'sondageRecherche.estActif': false,
        });
      } else {
        await docRef.update({
          'rechercheColocActive': false,
          'sondageRecherche.estActif': false,
        });
      }
    }
  }

  Future<void> _relancerSondage() async {
    if (_relanceEnCours) return;
    setState(() => _relanceEnCours = true);

    try {
      final docRef = _firestore
          .collection('conversations')
          .doc(widget.conversationId);
      await docRef.update({
        'sondageRecherche': {'estActif': true, 'votes': {}},
      });
    } finally {
      if (mounted) {
        setState(() => _relanceEnCours = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final sondageData =
            data['sondageRecherche'] as Map<String, dynamic>? ?? {};
        final sondageActif = sondageData['estActif'] as bool? ?? false;
        final rechercheColocActive = data['rechercheColocActive'] as bool?;
        final votes = sondageData['votes'] as Map<String, dynamic>? ?? {};

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (sondageActif)
                  _buildSondageActif(votes)
                else if (rechercheColocActive == true)
                  _buildResultatRechercheActive()
                else
                  _buildResultatEquipeComplete(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSondageActif(Map<String, dynamic> votes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Êtes-vous toujours à la recherche d'autres colocataires ?",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A5F),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.membres.map((uid) {
          return _buildVoteStatus(uid, votes[uid]);
        }),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _voteEnCours ? null : () => _voter('non'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                ),
                child: const Text("Non, l'équipe est complète"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _voteEnCours ? null : () => _voter('oui'),
                child: const Text('Oui, on cherche'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultatRechercheActive() {
    return Column(
      children: [
        const Icon(Icons.search_rounded, color: Colors.green, size: 32),
        const SizedBox(height: 8),
        const Text(
          "La recherche de colocataires est active !",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _relanceEnCours ? null : _relancerSondage,
          child: const Text("Relancer un vote"),
        ),
      ],
    );
  }

  Widget _buildResultatEquipeComplete() {
    return Column(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF1E3A5F),
          size: 32,
        ),
        const SizedBox(height: 8),
        const Text(
          "L'équipe est considérée comme complète.",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _relanceEnCours ? null : _relancerSondage,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.black87,
          ),
          child: const Text("Proposer de chercher à nouveau"),
        ),
      ],
    );
  }

  Widget _buildVoteStatus(String uid, String? vote) {
    final estMoi = uid == _currentUid;

    return FutureBuilder(
      future: UserService().recupererUtilisateur(uid),
      builder: (context, snapshot) {
        final prenom = snapshot.data?.prenom ?? 'Membre';
        final nomAffiche = estMoi ? '$prenom (Vous)' : prenom;

        IconData icon;
        Color color;
        String texte;

        switch (vote) {
          case 'oui':
            icon = Icons.check_circle_outline_rounded;
            color = Colors.green;
            texte = 'veut continuer à chercher';
            break;
          case 'non':
            icon = Icons.highlight_off_rounded;
            color = Colors.red;
            texte = 'veut compléter l\'équipe';
            break;
          default:
            icon = Icons.hourglass_empty_rounded;
            color = Colors.grey;
            texte = 'en attente de vote...';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: '$nomAffiche ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: texte,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
