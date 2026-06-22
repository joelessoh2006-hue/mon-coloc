import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/services/admin_service.dart';
import 'package:mon_coloc/services/user_service.dart';

/// Écran du back-office administrateur pour la modération.
/// Contient deux onglets : Logements (en_attente) et Bailleurs (en_attente).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final AdminService _adminService = AdminService();
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          unselectedLabelColor: theme.colorScheme.onErrorContainer
              .withOpacity(0.6),
          tabs: const [
            Tab(icon: Icon(Icons.home_rounded), text: 'Logements'),
            Tab(icon: Icon(Icons.people_rounded), text: 'Bailleurs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogementsTab(),
          _buildBailleursTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ONGLET LOGEMENTS
  // ---------------------------------------------------------------------------
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
            return _buildLogementCard(logementId, data);
          },
        );
      },
    );
  }

  Widget _buildLogementCard(String logementId, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final loyer = data['loyer'] ?? 0;
    final pieces = data['nombrePieces'] ?? 0;
    final commune = data['commune'] ?? 'Non spécifié';
    final quartier = data['quartier'] ?? '';
    final description = data['description'] ?? '';
    final datePublication = data['datePublication'] as Timestamp?;
    final dateStr = datePublication != null
        ? '${datePublication.toDate().day}/${datePublication.toDate().month}/${datePublication.toDate().year}'
        : 'Date inconnue';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : Type et statut
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_empty,
                          size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'En attente',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Localisation
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 20, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$commune${quartier.isNotEmpty ? ' — $quartier' : ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Loyer et pièces
            Row(
              children: [
                _infoChip(
                    Icons.monetization_on_rounded,
                    '${_formatMontant(loyer)} FCFA/mois',
                    Colors.green.shade700),
                const SizedBox(width: 12),
                _infoChip(Icons.meeting_room_rounded, '$pieces pièce(s)',
                    Colors.blue.shade700),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _confirmerRejet('logement', logementId, data),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Rejeter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        _confirmerApprobation('logement', logementId),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approuver'),
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
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ONGLET BAILLEURS
  // ---------------------------------------------------------------------------
  Widget _buildBailleursTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminService.ecouterBailleursEnAttente(),
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
            icon: Icons.people_rounded,
            message: 'Aucun bailleur en attente de validation',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          itemBuilder: (_, index) {
            final doc = documents[index];
            final data = doc.data() as Map<String, dynamic>;
            final bailleurUid = doc.id;
            return _buildBailleurCard(bailleurUid, data);
          },
        );
      },
    );
  }

  Widget _buildBailleurCard(String bailleurUid, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final nom = data['nom'] ?? '';
    final prenom = data['prenom'] ?? '';
    final email = data['email'] ?? '';
    final telephone = data['telephone'] ?? '';
    final ecole = data['ecoleUniversite'] ?? '';
    final photoUrl = data['photoUrl'] as String?;
    final justificatifUrl = data['justificatifUrl'] as String?;
    final dateInscription = data['dateInscription'] as Timestamp?;
    final dateStr = dateInscription != null
        ? '${dateInscription.toDate().day}/${dateInscription.toDate().month}/${dateInscription.toDate().year}'
        : 'Date inconnue';

    final initiale = (prenom as String).isNotEmpty
        ? prenom[0].toUpperCase()
        : (nom as String).isNotEmpty
            ? nom[0].toUpperCase()
            : '?';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec avatar
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          initiale,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
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
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge "En attente"
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_empty,
                          size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'en_attente',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Informations
            if (telephone.isNotEmpty) ...[
              _infoRow(Icons.phone_rounded, 'Tél : $telephone'),
              const SizedBox(height: 4),
            ],
            if (ecole.isNotEmpty) ...[
              _infoRow(Icons.school_rounded, 'École : $ecole'),
              const SizedBox(height: 4),
            ],
            _infoRow(Icons.calendar_today_rounded, 'Inscrit le $dateStr'),

            // Justificatif (CNI)
            if (justificatifUrl != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.document_scanner_rounded,
                      size: 18, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  const Text(
                    'Document justificatif (CNI)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _afficherJustificatif(justificatifUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_rounded,
                              size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Voir',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _confirmerRejet('bailleur', bailleurUid, data),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Rejeter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        _confirmerApprobation('bailleur', bailleurUid),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approuver'),
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
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AIDE VISUELLE
  // ---------------------------------------------------------------------------

  Widget _infoChip(IconData icon, String texte, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            texte,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String texte) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texte,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

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

  String _formatMontant(dynamic montant) {
    if (montant == null) return '0';
    final nombre = montant is int ? montant : int.tryParse(montant.toString()) ?? 0;
    final str = nombre.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // DIALOGUES DE CONFIRMATION
  // ---------------------------------------------------------------------------

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
          content: Text(
              '$typeLabel a été approuvé avec succès ✓'),
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
      String type, String id, Map<String, dynamic> data) async {
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
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

  /// Affiche un document justificatif en plein écran.
  void _afficherJustificatif(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Document justificatif'),
          ),
          body: InteractiveViewer(
            child: Center(
              child: Image.network(
                url,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_rounded,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Impossible de charger l\'image'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}