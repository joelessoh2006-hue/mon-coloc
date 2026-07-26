import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../chat_screen.dart';
import 'widgets/admin_bailleur_card.dart';
import 'widgets/admin_etudiant_card.dart';
import 'widgets/admin_logement_card.dart';
/// Écran du back-office administrateur complet.
/// 5 onglets : Logements, Bailleurs en attente, Étudiants, Comptes Bloqués, Signalements.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final AdminService _adminService = AdminService();
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🛡️ Panel Admin',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.errorContainer,
        foregroundColor: theme.colorScheme.onErrorContainer,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.error,
          labelColor: theme.colorScheme.onErrorContainer,
          unselectedLabelColor: theme.colorScheme.onErrorContainer.withOpacity(
            0.6,
          ),
          isScrollable: true,
          tabs: [
            _buildTabWithBadge(
              icon: Icons.home_rounded,
              text: 'Logements',
              stream: _adminService.ecouterLogementsEnAttente(),
            ),
            _buildTabWithBadge(
              icon: Icons.people_rounded,
              text: 'Bailleurs',
              stream: _adminService.ecouterBailleursEnAttenteDeValidation(),
            ),
            _buildTabWithBadge(
              icon: Icons.school_rounded,
              text: 'Étudiants',
              // Le badge compte les étudiants en attente de vérification de document
              stream: _adminService.ecouterEtudiantsEnAttenteDeValidation(),
            ),
            const Tab(icon: Icon(Icons.block_rounded), text: 'Comptes Bloqués'),
            _buildTabWithBadge(
              icon: Icons.report_problem_rounded,
              text: 'Signalements',
              stream: _adminService.ecouterSignalements(),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogementsTab(),
          _buildBailleursTab(),
          _buildEtudiantsTab(),
          _buildComptesBloquesTab(),
          _buildSignalementsTab(),
        ],
      ),
    );
  }

  Widget _buildTabWithBadge({
    required IconData icon,
    required String text,
    required Stream<QuerySnapshot> stream,
    bool Function(DocumentSnapshot)? filter,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Tab(icon: Icon(icon), text: text);
        }
        final docs = filter != null
            ? snapshot.data!.docs.where(filter).toList()
            : snapshot.data!.docs;
        final count = docs.length;

        return Badge(
          label: Text('$count'),
          isLabelVisible: count > 0,
          child: Tab(icon: Icon(icon), text: text),
        );
      },
    );
  }

  // ===========================================================================
  // ONGLET LOGEMENTS
  // ===========================================================================
  Widget _buildLogementsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminService.ecouterLogementsEnAttente(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur : ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return _buildEmptyState(
            icon: Icons.home_rounded,
            message: 'Aucun logement en attente de validation',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          itemBuilder: (_, index) {
            final doc = documents[index];
            final data = doc.data() as Map<String, dynamic>;
            final logementId = doc.id;
            return AdminLogementCard(
              logementId: logementId,
              data: data,
              onApprouver: (id) => _confirmerApprobation('logement', id),
              onRejeter: (id, data) => _confirmerRejet('logement', id, data),
              onAfficherMedia: _afficherMediaDialog,
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // ONGLET BAILLEURS
  // ===========================================================================
  Widget _buildBailleursTab() {
    // Filtre strict : Écoute UNIQUEMENT les comptes où role == 'bailleur', estVerifie == false ET estBloque == false.
    return StreamBuilder<QuerySnapshot>(
      stream: _adminService.ecouterBailleursEnAttenteDeValidation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur : ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final bailleurs = snapshot.data?.docs ?? [];

        if (bailleurs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_rounded,
            message: 'Aucun bailleur en attente de validation',
          );
        }

        bailleurs.sort((a, b) {
          return (b.data() as Map<String, dynamic>)['dateInscription']
              .compareTo((a.data() as Map<String, dynamic>)['dateInscription']);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bailleurs.length,
          itemBuilder: (_, index) {
            final doc = bailleurs[index];
            final data = doc.data() as Map<String, dynamic>;
            final bailleurUid = doc.id;
            return AdminBailleurCard(
              uid: bailleurUid,
              data: data,
              onApprouver: (uid) => _confirmerApprobation('bailleur', uid),
              onBloquerDebloquer: _confirmerBlocageDeblocage,
              onAfficherJustificatif: _afficherJustificatif,
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // ONGLET ÉTUDIANTS
  // ===========================================================================
  Widget _buildEtudiantsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminService.ecouterEtudiantsEnAttenteDeValidation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur : ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return _buildEmptyState(
            icon: Icons.school_rounded,
            message: 'Aucun étudiant en attente de vérification',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'Étudiants à vérifier (${documents.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: documents.length,
                itemBuilder: (_, index) {
                  final doc = documents[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final uid = doc.id;
                  return AdminEtudiantCard(
                    uid: uid,
                    data: data,
                    onVerifier: _confirmerVerificationEtudiant,
                    onBloquerDebloquer: _confirmerBlocageDeblocage,
                    onAfficherJustificatif: _afficherJustificatif,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
    
  }

  // ===========================================================================
  // ONGLET COMPTES BLOQUÉS
  // ===========================================================================
  Widget _buildComptesBloquesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminService.ecouterComptesBloques(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur : ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return _buildEmptyState(
            icon: Icons.block_rounded,
            message: 'Aucun compte bloqué pour le moment',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          itemBuilder: (_, index) {
            final doc = documents[index];
            final data = doc.data() as Map<String, dynamic>;
            final uid = doc.id;
            return _buildCompteBloqueCard(uid, data);
          },
        );
      },
    );
  }

  Widget _buildCompteBloqueCard(String uid, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final nom = data['nom'] ?? '';
    final prenom = data['prenom'] ?? '';
    final role = data['role'] as String? ?? 'Inconnu';
    final dateBlocage = data['dateBlocage'] as Timestamp?;
    final dateStr = dateBlocage != null
        ? '${dateBlocage.toDate().day}/${dateBlocage.toDate().month}/${dateBlocage.toDate().year}'
        : 'Date inconnue';
    final explicationsRecours = data['explicationsRecours'] as String?;

    final initiale = prenom.isNotEmpty
        ? prenom[0].toUpperCase()
        : nom.isNotEmpty
        ? nom[0].toUpperCase()
        : '?';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.errorContainer,
                  child: Text(
                    initiale,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$prenom $nom',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rôle : ${role[0].toUpperCase()}${role.substring(1)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(estVerifie: false, estBloque: true),
              ],
            ),
            const SizedBox(height: 12),
           Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Icon(Icons.comment_rounded, size: 16, color: Colors.grey.shade600),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        'Recours : $explicationsRecours',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      ),
    ),
  ],
),
            if (explicationsRecours != null &&
                explicationsRecours.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.comment_rounded, 'Recours : $explicationsRecours'),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    _confirmerBlocageDeblocage(uid, nom, prenom, true),
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Débloquer le compte'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ONGLET SIGNALEMENTS
  // ===========================================================================
  Widget _buildSignalementsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminService.ecouterSignalements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur : ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return _buildEmptyState(
            icon: Icons.report_problem_rounded,
            message: 'Aucun signalement pour le moment',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          itemBuilder: (_, index) {
            final doc = documents[index];
            final data = doc.data() as Map<String, dynamic>;
            final reportId = doc.id;
            return _buildSignalementCard(reportId, data);
          },
        );
      },
    );
  }

  Widget _buildSignalementCard(String reportId, Map<String, dynamic> data) {
    // Supporter plusieurs formats de signalements (anciens/nouveaux)
    final motif = data['motif'] ?? data['motifSignalement'] ?? 'Non spécifié';
    final description = data['description'] ?? data['details'] ?? '';
    final typeReport =
        data['type'] as String? ?? data['typeSignalement'] as String? ?? '';
    final typeSignalement = data['typeSignalement'] as String? ?? typeReport;
    final cibleId =
        data['cibleId'] as String? ??
        data['idUtilisateurSignale'] as String? ??
        data['idElement'] as String? ??
        '';
    final cibleNom =
        data['cibleNom'] as String? ?? data['cibleNomelle'] as String? ?? '';
    final auteurNom =
        data['auteurNom'] as String? ?? data['auteurNom'] as String? ?? '';
    final conversationId = data['conversationId'] as String?;
    final dateCreation =
        (data['dateCreation'] as Timestamp?) ??
        (data['dateSignalement'] as Timestamp?);
    final dateStr = dateCreation != null
        ? '${dateCreation.toDate().day}/${dateCreation.toDate().month}/${dateCreation.toDate().year} ${dateCreation.toDate().hour}:${dateCreation.toDate().minute}'
        : 'Date inconnue';

    // Déterminer l'icône et le label du type de signalement
    IconData typeIcon;
    String typeLabel;
    if (typeReport == 'logement' || typeSignalement == 'logement') {
      typeIcon = Icons.home_rounded;
      typeLabel = 'Logement';
    } else if (typeSignalement == 'etudiant_vers_bailleur') {
      typeIcon = Icons.person_rounded;
      typeLabel = 'Étud. → Baill.';
    } else if (typeSignalement == 'bailleur_vers_etudiant') {
      typeIcon = Icons.business_rounded;
      typeLabel = 'Baill. → Étud.';
    } else if (typeSignalement == 'etudiant_vers_etudiant') {
      typeIcon = Icons.group_rounded;
      typeLabel = 'Étud. → Étud.';
    } else {
      // Fallback pour les anciens signalements ou 'utilisateur'
      typeIcon = Icons.person_rounded;
      typeLabel = 'Utilisateur';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        motif,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(typeIcon, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'De : $auteurNom',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Icon(
                  Icons.person_off_outlined,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Cible : $cibleNom',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmerSuppressionSignalement(reportId),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Ignorer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                // Afficher le bouton "Voir la conversation" SI conversationId existe
                if (conversationId != null && conversationId.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _voirConversation(
                        conversationId: conversationId,
                        auteurId: data['auteurId'] as String?,
                        cibleId: cibleId,
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('Voir conv.'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: cibleId.isEmpty
                        ? null
                        : () => _confirmerBlocageDepuisReport(
                            typeReport,
                            cibleId,
                            cibleNom,
                            reportId,
                          ),
                    icon: const Icon(Icons.block_rounded, size: 18),
                    label: const Text('Bloquer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  // ===========================================================================
  // NAVIGATION & ACTIONS
  // ===========================================================================

  /// Ouvre l'écran de chat pour une conversation liée à un signalement.
  Future<void> _voirConversation({
    String? conversationId,
    String? auteurId,
    String? cibleId,
  }) async {
    if (auteurId == null || cibleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'IDs des participants manquants pour trouver la conversation.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? finalConversationId = conversationId;

    // Si l'ID de conversation n'est pas directement dans le signalement,
    // on essaie de le trouver avec les IDs des membres.
    if (finalConversationId == null || finalConversationId.isEmpty) {
      finalConversationId = await _chatService.trouverConversationParMembres(
        auteurId,
        cibleId,
      );
    }

    if (finalConversationId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucune conversation trouvée entre ces deux utilisateurs.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: finalConversationId,
            // Pour l'admin, le destinataire est arbitraire, on prend la cible.
            destinataireId: cibleId,
            // On passe l'auteur comme "participant 1" pour que ses bulles
            // s'affichent à gauche, et celles de la cible à droite.
            participantUnId: auteurId,
            estModeAdmin: true,
          ),
        ),
      );
    }
  }

  // ===========================================================================
  // MÉDIAS : Boîte de dialogue pour visualiser les photos
  // ===========================================================================
  void _afficherMediaDialog(List<String> urls) {
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune photo disponible pour ce logement'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AppBar interne
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image_rounded),
                  const SizedBox(width: 8),
                  const Text(
                    'Photos du logement',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            // Carousel
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: urls.length,
                itemBuilder: (context, index) {
                  final raw = urls[index];
                  Uint8List? bytes;
                  try {
                    if (raw.startsWith('data:image')) {
                      final base64Part = raw.split(',').last;
                      bytes = base64Decode(base64Part);
                    } else {
                      bytes = base64Decode(raw);
                    }
                  } catch (_) {
                    bytes = null;
                  }

                  return InteractiveViewer(
                    child: Center(
                      child: bytes != null
                          ? Image.memory(bytes, fit: BoxFit.contain)
                          : Image.network(
                              raw,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_rounded,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
            // Indicateur de page
            if (urls.length > 1)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '1 / ${urls.length}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Affiche un document justificatif en plein écran.
  void _afficherJustificatif(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Document justificatif')),
          body: InteractiveViewer(
            child: Center(
              child: Builder(
                builder: (_) {
                  Uint8List? bytes;
                  try {
                    if (url.startsWith('data:image')) {
                      final base64Part = url.split(',').last;
                      bytes = base64Decode(base64Part);
                    }
                  } catch (_) {
                    bytes = null;
                  }

                  if (bytes != null) {
                    return Image.memory(bytes);
                  }

                  // Fallback pour les anciennes URLs de Firebase Storage
                  return Image.network(
                    url,
                    errorBuilder: (_, __, ___) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_rounded, size: 48),
                        SizedBox(height: 8),
                        Text('Impossible d\'afficher le document'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // AIDE VISUELLE
  // ===========================================================================
  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // DIALOGUES DE CONFIRMATION
  // ===========================================================================

  Future<void> _confirmerApprobation(String type, String id) async {
    final typeLabel = type == 'logement' ? 'ce logement' : 'ce compte bailleur';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('✅ Confirmer l\'approbation'),
        content: Text('Êtes-vous sûr de vouloir approuver $typeLabel ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approuver'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (type == 'logement') {
        await _adminService.approuverLogement(id);
      } else {
        await _adminService.approuverBailleur(id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$typeLabel a été approuvé avec succès ✓'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'approbation : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmerRejet(
    String type,
    String id,
    Map<String, dynamic> data,
  ) async {
    final typeLabel = type == 'logement' ? 'ce logement' : 'ce compte bailleur';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('❌ Confirmer le rejet'),
        content: Text('Êtes-vous sûr de vouloir rejeter $typeLabel ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (type == 'logement') {
        await _adminService.rejeterLogement(id);
      } else {
        await _adminService.rejeterBailleur(id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$typeLabel a été rejeté.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du rejet : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmerVerificationEtudiant(
    String uid,
    bool actuellementVerifie,
  ) async {
    final action = actuellementVerifie
        ? 'retirer la vérification de'
        : 'vérifier';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          actuellementVerifie
              ? '↩️ Rétirer la vérification'
              : '✅ Vérifier l\'étudiant',
        ),
        content: Text('Êtes-vous sûr de vouloir $action cet étudiant ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: actuellementVerifie
                  ? Colors.orange
                  : Colors.green,
            ),
            child: Text(actuellementVerifie ? 'Rétirer' : 'Vérifier'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (actuellementVerifie) {
        await _adminService.deverifierEtudiant(uid);
      } else {
        await _adminService.verifierEtudiant(uid);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actuellementVerifie ? 'Vérification retirée' : 'Étudiant vérifié ✓',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmerBlocageDeblocage(
    String uid,
    String nom,
    String prenom,
    bool actuellementBloque,
  ) async {
    final action = actuellementBloque ? 'débloquer' : 'bloquer';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          actuellementBloque
              ? '🔓 Confirmer le déblocage'
              : '🔒 Confirmer le blocage',
        ),
        content: Text(
          'Êtes-vous sûr de vouloir $action le compte de $prenom $nom ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: actuellementBloque ? Colors.green : Colors.red,
            ),
            child: Text(actuellementBloque ? 'Débloquer' : 'Bloquer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (actuellementBloque) {
        await _adminService.debloquerCompte(uid);
      } else {
        await _adminService.bloquerCompte(uid);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actuellementBloque ? 'Compte débloqué' : 'Compte bloqué',
          ),
          backgroundColor: actuellementBloque ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmerBlocageDepuisReport(
    String typeReport,
    String cibleId,
    String cibleNom,
    String reportId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔒 Bloquer le compte'),
        content: Text(
          'Voulez-vous bloquer le compte de $cibleNom suite à ce signalement ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      String uidToBlock = cibleId;

      if (typeReport == 'logement') {
        final logementDoc = await FirebaseFirestore.instance
            .collection('logements')
            .doc(cibleId)
            .get();

        if (!logementDoc.exists) {
          throw Exception('Logement introuvable pour cet ID de signalement.');
        }

        final logementData = logementDoc.data() as Map<String, dynamic>?;
        uidToBlock = logementData?['idBailleur'] as String? ?? '';

        if (uidToBlock.isEmpty) {
          throw Exception('Aucun bailleur trouvé pour ce logement.');
        }
      }

      if (uidToBlock.isEmpty) {
        throw Exception('Aucun utilisateur à bloquer.');
      }

      await _adminService.bloquerCompte(uidToBlock);
      await _adminService.supprimerSignalement(reportId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte bloqué et signalement traité'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmerSuppressionSignalement(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗑️ Ignorer le signalement'),
        content: const Text(
          'Ce signalement sera supprimé sans action sur le compte concerné.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.grey),
            child: const Text('Ignorer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _adminService.supprimerSignalement(reportId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signalement ignoré'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
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

class _StatusBadge extends StatelessWidget {
  final bool estVerifie;
  final bool estBloque;

  const _StatusBadge({required this.estVerifie, required this.estBloque});

  @override
  Widget build(BuildContext context) {
    if (estBloque) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
        child: Text('BLOQUÉ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
      );
    }
    if (estVerifie) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
        child: Text('✓ Vérifié', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
      child: Text('En attente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
    );
  }
}
