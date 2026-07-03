import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/services/admin_service.dart';
import 'package:mon_coloc/services/user_service.dart';

/// Écran du back-office administrateur complet.
/// 4 onglets : Logements, Bailleurs, Étudiants, Signalements.
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
    _tabController = TabController(length: 4, vsync: this);
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
          tabs: const [
            Tab(icon: Icon(Icons.home_rounded), text: 'Logements'),
            Tab(icon: Icon(Icons.people_rounded), text: 'Bailleurs'),
            Tab(icon: Icon(Icons.school_rounded), text: 'Étudiants'),
            Tab(icon: Icon(Icons.flag_rounded), text: 'Signalements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogementsTab(),
          _buildBailleursTab(),
          _buildEtudiantsTab(),
          _buildSignalementsTab(),
        ],
      ),
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
    final photos = _safeStringList(
      data['logementPhotos'] ?? data['photos'] ?? data['imageUrls'] ?? [],
    );
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
            // En-tête : Statut badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hourglass_empty,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mini carousel des photos
            if (photos.isNotEmpty) ...[
              SizedBox(
                height: 140,
                child: PageView.builder(
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _afficherMediaDialog(photos),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(photos[index]),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              // Pas de photos : bouton pour en ouvrir si jamais
              SizedBox(
                height: 100,
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _afficherMediaDialog(photos),
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Aucune photo'),
                  ),
                ),
              ),
            ],

            // Localisation
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 20,
                  color: Colors.red.shade400,
                ),
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
                  Colors.green.shade700,
                ),
                const SizedBox(width: 12),
                _infoChip(
                  Icons.meeting_room_rounded,
                  '$pieces pièce(s)',
                  Colors.blue.shade700,
                ),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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

  // ===========================================================================
  // ONGLET BAILLEURS
  // ===========================================================================
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

  Widget _buildBailleurCard(String uid, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final nom = data['nom'] ?? '';
    final prenom = data['prenom'] ?? '';
    final email = data['email'] ?? '';
    final telephone = data['telephone'] ?? '';
    final ecole = data['ecoleUniversite'] ?? '';
    final photoUrl = data['photoUrl'] as String?;
    final justificatifUrl = data['justificatifUrl'] as String?;
    final estVerifie = data['estVerifie'] as bool? ?? false;
    final estBloque = data['estBloque'] as bool? ?? false;
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
            // En-tête
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
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
                Column(
                  children: [
                    if (estVerifie)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '✓ Vérifié',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'en_attente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    if (estBloque) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'BLOQUÉ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (telephone.isNotEmpty) ...[
              _infoRow(Icons.phone_rounded, 'Tél : $telephone'),
              const SizedBox(height: 4),
            ],
            if (ecole.isNotEmpty) ...[
              _infoRow(Icons.school_rounded, 'École : $ecole'),
              const SizedBox(height: 4),
            ],
            _infoRow(Icons.calendar_today_rounded, 'Inscrit le $dateStr'),

            // Document justificatif (CNI)
            if (justificatifUrl != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.document_scanner_rounded,
                    size: 18,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Document justificatif (CNI)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _afficherJustificatif(justificatifUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_rounded,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
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
                // Bouton bloquer/débloquer
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _confirmerBlocageDeblocage(uid, nom, prenom, estBloque),
                    icon: Icon(
                      estBloque ? Icons.lock_open_rounded : Icons.block_rounded,
                      size: 18,
                    ),
                    label: Text(estBloque ? 'Débloquer' : 'Bloquer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: estBloque
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      side: BorderSide(
                        color: estBloque
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (!estBloque) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _confirmerApprobation('bailleur', uid),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ONGLET ÉTUDIANTS
  // ===========================================================================
  Widget _buildEtudiantsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminService.ecouterEtudiantsAVerifier(),
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

        final documents = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final justificatifUrl = data['justificatifUrl'] as String?;
          return justificatifUrl != null && justificatifUrl.isNotEmpty;
        }).toList();

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
                'Étudiants non vérifiés (${documents.length})',
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
                  return _buildEtudiantCard(uid, data);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEtudiantCard(String uid, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final nom = data['nom'] ?? '';
    final prenom = data['prenom'] ?? '';
    final email = data['email'] ?? '';
    final telephone = data['telephone'] ?? '';
    final ecole = data['ecoleUniversite'] ?? '';
    final filiere = data['filiere'] ?? '';
    final photoUrl = data['photoUrl'] as String?;
    final justificatifUrl = data['justificatifUrl'] as String?;
    final estVerifie = data['estVerifie'] as bool? ?? false;
    final estBloque = data['estBloque'] as bool? ?? false;
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
        side: BorderSide(
          color: estVerifie ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
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
                Column(
                  children: [
                    if (estVerifie)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '✓ Vérifié',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Non vérifié',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    if (estBloque) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'BLOQUÉ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (telephone.isNotEmpty) ...[
              _infoRow(Icons.phone_rounded, 'Tél : $telephone'),
              const SizedBox(height: 4),
            ],
            if (ecole.isNotEmpty)
              _infoRow(Icons.school_rounded, 'École : $ecole'),
            if (filiere.isNotEmpty) ...[
              const SizedBox(height: 4),
              _infoRow(Icons.menu_book_rounded, 'Filière : $filiere'),
            ],
            const SizedBox(height: 4),
            _infoRow(Icons.calendar_today_rounded, 'Inscrit le $dateStr'),

            // Document justificatif (carte d'étudiant / CNI)
            if (justificatifUrl != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.document_scanner_rounded,
                    size: 18,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Pièce d\'identité',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _afficherJustificatif(justificatifUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_rounded,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
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
                // Bouton bloquer/débloquer
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _confirmerBlocageDeblocage(uid, nom, prenom, estBloque),
                    icon: Icon(
                      estBloque ? Icons.lock_open_rounded : Icons.block_rounded,
                      size: 18,
                    ),
                    label: Text(estBloque ? 'Débloquer' : 'Bloquer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: estBloque
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      side: BorderSide(
                        color: estBloque
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (!estBloque) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _confirmerVerificationEtudiant(uid, estVerifie),
                      icon: Icon(
                        estVerifie
                            ? Icons.undo_rounded
                            : Icons.verified_user_rounded,
                        size: 18,
                      ),
                      label: Text(estVerifie ? 'Rétirer' : 'Vérifier'),
                      style: FilledButton.styleFrom(
                        backgroundColor: estVerifie
                            ? Colors.orange.shade600
                            : Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
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
            icon: Icons.flag_rounded,
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
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Conversation : ${data['idElement'] ?? 'Inconnue'}'),
    behavior: SnackBarBehavior.floating,
  ),
);
                      },
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
                    } else {
                      bytes = base64Decode(url);
                    }
                  } catch (_) {
                    bytes = null;
                  }

                  if (bytes != null) {
                    return Image.memory(bytes);
                  }

                  return Image.network(
                    url,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_rounded),
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
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
    final nombre = montant is int
        ? montant
        : int.tryParse(montant.toString()) ?? 0;
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

  /// Convertit un champ potentiellement List ou null en List<String>.
  List<String> _safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value.map((e) => e.toString()));
    if (value is String) return [value];
    return [];
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
