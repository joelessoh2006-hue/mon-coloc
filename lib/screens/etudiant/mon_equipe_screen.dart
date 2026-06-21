import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/screens/chat_screen.dart';
import 'package:mon_coloc/services/chat_service.dart';
import 'package:mon_coloc/services/equipe_service.dart';

/// Écran "Mon Équipe" — Hub de discussion pour les colocations.
///
/// Affiche dans une seule vue scrollable :
/// 1. L'espace Équipe Officielle (si une colocation est acceptée) avec TOUS les membres
/// 2. Les autres discussions / demandes en attente
class MonEquipeScreen extends StatefulWidget {
const MonEquipeScreen({super.key});

  @override
  State<MonEquipeScreen> createState() => _MonEquipeScreenState();
}

class _MonEquipeScreenState extends State<MonEquipeScreen> {
  final ChatService _chatService = ChatService();
  final EquipeService _equipeService = EquipeService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
  Future<Map<String, Map<String, dynamic>?>> _recupererInfosMultiplesUtilisateurs(
      List<String> uids) async {
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
                  'Chargement de vos discussions…',
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
                  Icon(Icons.error_outline_rounded,
                      size: 64, color: Colors.red.shade300),
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

        // Trier par misAJourLe descendant (côté Dart)
        conversationsBrutes.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final tsA = (dataA['misAJourLe'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final tsB = (dataB['misAJourLe'] as Timestamp?)?.toDate() ?? DateTime(2000);
          return tsB.compareTo(tsA);
        });

        final conversations = conversationsBrutes;

        // Séparer les conversations acceptées des autres
        final conversationsAcceptees = conversations.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['demandeStatut'] == 'accepte';
        }).toList();

        final conversationsNonAcceptees = conversations.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['demandeStatut'] != 'accepte';
        }).toList();

        return _buildVueComplete(
          currentUser,
          conversationsAcceptees.isNotEmpty
              ? conversationsAcceptees.first
              : null,
          conversationsNonAcceptees,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // VUE COMPLÈTE (Section Équipe Officielle + Autres discussions)
  // ---------------------------------------------------------------------------

  /// Construit la vue scrollable complète :
  /// - Section 1 : Espace Équipe Officiel (si accepté) avec TOUS les membres
  /// - Section 2 : Demandes reçues / autres discussions
  Widget _buildVueComplete(
    User currentUser,
    DocumentSnapshot? conversationAcceptee,
    List<QueryDocumentSnapshot> conversationsNonAcceptees,
  ) {
    // Filtrer : Demandes reçues = en_attente ET proposePar != currentUser
    final demandesRecues = conversationsNonAcceptees.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final statut = data['demandeStatut'] as String?;
      final proposePar = data['proposePar'] as String?;
      return statut == 'en_attente' && proposePar != currentUser.uid;
    }).toList();

    // Filtrer : Vos Discussions = les autres conversations actives
    final vosDiscussions = conversationsNonAcceptees.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final statut = data['demandeStatut'] as String?;
      final proposePar = data['proposePar'] as String?;
      return !(statut == 'en_attente' && proposePar != currentUser.uid);
    }).toList();

    final bool aDesAutresConversations =
        demandesRecues.isNotEmpty || vosDiscussions.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // ================================================================
          // SECTION 1 : ESPACE ÉQUIPE OFFICIELLE (si colocation acceptée)
          // ================================================================
          if (conversationAcceptee != null)
            _buildEspaceEquipeOfficielle(currentUser, conversationAcceptee),

          if (conversationAcceptee != null && aDesAutresConversations)
            const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 8),
              child: Divider(height: 1, thickness: 1),
            ),

          // ================================================================
          // SECTION 2 : AUTRES DISCUSSIONS & INVITATIONS
          // ================================================================

          // --- Section Demandes reçues ---
          if (demandesRecues.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Demandes en attente',
              subtitle: 'Ces étudiants veulent former une équipe avec vous',
            ),
            const SizedBox(height: 8),
            ...demandesRecues.map((doc) => _buildDemandeRecueCard(
                  currentUser,
                  doc,
                )),
            const SizedBox(height: 24),
          ],

          // --- Section Vos Discussions ---
          if (vosDiscussions.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Vos autres discussions',
              subtitle: 'Discussions en cours avec d\'autres étudiants',
            ),
            const SizedBox(height: 8),
            ...vosDiscussions.map((doc) => _buildDiscussionCard(
                  currentUser,
                  doc,
                )),
          ],

          // --- Message si absolument rien ---
          if (conversationAcceptee == null &&
              demandesRecues.isEmpty &&
              vosDiscussions.isEmpty)
            _buildEmptyState(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ESPACE ÉQUIPE OFFICIELLE (Multi-membres)
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
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
                  const Text(
                    '🎉',
                    style: TextStyle(fontSize: 48),
                  ),
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

            const SizedBox(height: 24),

            // Section : Membres de l'équipe
            Row(
              children: [
                const Icon(Icons.group_rounded, size: 20, color: Color(0xFF1E3A5F)),
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
            ...autresMembres.map((uid) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildMembreCard(
                    uid: uid,
                    infos: infosMap[uid],
                    estMoi: false,
                  ),
                )),

            const SizedBox(height: 20),

            // Bouton : Discussion d'équipe
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
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
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
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
                        Icon(Icons.school_rounded,
                            size: 14, color: Colors.grey[500]),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit l'état vide quand il n'y a aucune conversation.
  Widget _buildEmptyState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              'Aucune discussion pour le moment',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Explorez les profils dans l\'onglet Découvrir\npour trouver votre futur colocataire !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.4,
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
  Widget _buildDemandeRecueCard(
    User currentUser,
    QueryDocumentSnapshot doc,
  ) {
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

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: InkWell(
            onTap: () => _ouvrirChat(conversationId, proposePar),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Demande en attente',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Flèche
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CARTE DISCUSSION
  // ---------------------------------------------------------------------------

  /// Construit une carte pour une discussion active.
  Widget _buildDiscussionCard(
    User currentUser,
    QueryDocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final conversationId = doc.id;
    final membres = List<String>.from(data['membres'] as List);
    final dernierMessage = data['dernierMessage'] as String? ?? '';
    final misAJourLe = data['misAJourLe'] as Timestamp?;
    final demandeStatut = data['demandeStatut'] as String?;

    // Identifier l'autre membre
    final autreId =
        membres.where((id) => id != currentUser.uid).firstOrNull ?? '';

    String statutLabel;
    Color statutCouleur;
    IconData statutIcone;

    switch (demandeStatut) {
      case 'en_attente':
        statutLabel = 'En attente';
        statutCouleur = const Color(0xFF1565C0);
        statutIcone = Icons.hourglass_empty_rounded;
        break;
      case 'refuse':
        statutLabel = 'Refusée';
        statutCouleur = Colors.red;
        statutIcone = Icons.cancel_outlined;
        break;
      default:
        statutLabel = 'Active';
        statutCouleur = Colors.grey;
        statutIcone = Icons.chat_rounded;
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _recupererInfosUtilisateur(autreId),
      builder: (context, snapshot) {
        final infos = snapshot.data;
        final prenom = infos?['prenom'] as String? ?? 'Inconnu';
        final nom = infos?['nom'] as String? ?? '';
        final photoUrl = infos?['photoUrl'] as String?;

        // Formater le timestamp
        String tempsAffiche = '';
        if (misAJourLe != null) {
          final date = misAJourLe.toDate();
          final maintenant = DateTime.now();
          final difference = maintenant.difference(date);

          if (difference.inMinutes < 1) {
            tempsAffiche = 'À l\'instant';
          } else if (difference.inHours < 1) {
            tempsAffiche = 'Il y a ${difference.inMinutes} min';
          } else if (difference.inDays < 1) {
            tempsAffiche =
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          } else if (difference.inDays == 1) {
            tempsAffiche = 'Hier';
          } else if (difference.inDays < 7) {
            tempsAffiche = 'Il y a ${difference.inDays} jours';
          } else {
            tempsAffiche =
                '${date.day}/${date.month}/${date.year}';
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () => _ouvrirChat(conversationId, autreId),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(
                            prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  // Contenu
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$prenom $nom',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A5F),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (tempsAffiche.isNotEmpty)
                              Text(
                                tempsAffiche,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Statut badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statutCouleur.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    statutIcone,
                                    size: 11,
                                    color: statutCouleur,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    statutLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: statutCouleur,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Dernier message
                            Expanded(
                              child: Text(
                                dernierMessage.isNotEmpty
                                    ? dernierMessage
                                    : 'Aucun message…',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
}