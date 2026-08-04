import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mon_coloc/models/visite_model.dart';
import 'package:mon_coloc/screens/chat_screen.dart';
import 'package:mon_coloc/services/chat_service.dart';
import 'package:mon_coloc/services/visite_service.dart';

/// Hub étudiant "Messagerie & Visites".
/// Contient deux onglets internes :
///  - "Messages" : liste des conversations
///  - "Suivi des Visites" : suivi en temps réel des demandes de visite
class EtudiantMessagerieScreen extends StatefulWidget {
  const EtudiantMessagerieScreen({super.key});

  @override
  State<EtudiantMessagerieScreen> createState() =>
      _EtudiantMessagerieScreenState();
}

class _EtudiantMessagerieScreenState extends State<EtudiantMessagerieScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final ChatService _chatService = ChatService();
  final VisiteService _visiteService = VisiteService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cache les infos des utilisateurs (prénom, nom, photo)
  final Map<String, Map<String, dynamic>?> _cacheInfos = {};

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
          'Messagerie & Visites',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Messages'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Suivi des Visites'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMessagesTab(),
          _buildVisitesTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ONGLET 1 : MESSAGES (Boîte de réception)
  // ---------------------------------------------------------------------------
  Widget _buildMessagesTab() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Utilisateur non connecté'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.ecouterConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Erreur : ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final conversations = snapshot.data?.docs ?? [];

        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded,
                    size: 72, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Aucune conversation pour le moment',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les messages apparaîtront ici\ndès que vous échangerez avec un bailleur',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }

        // Trier par dernier message (misAJourLe)
        final triees = List<QueryDocumentSnapshot>.from(conversations)
          ..sort((a, b) {
            final dateA = _getTimestamp(a, 'misAJourLe');
            final dateB = _getTimestamp(b, 'misAJourLe');
            return dateB.compareTo(dateA);
          });

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: triees.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
          itemBuilder: (context, index) {
            final conv = triees[index];
            final data = conv.data() as Map<String, dynamic>;
            final membres =
                List<String>.from(data['membres'] as List? ?? []);
            final dernierMessage =
                data['dernierMessage'] as String? ?? '';
            final nonLuPar =
                List<String>.from(data['nonLuPar'] as List? ?? []);
            final estNonLu = nonLuPar.contains(uid);

            // Déterminer l'autre participant (pas l'étudiant connecté)
            final autreId = membres.firstWhere(
              (id) => id != uid,
              orElse: () => '',
            );

            if (autreId.isEmpty) return const SizedBox.shrink();

            return _buildConversationTile(
              conversationId: conv.id,
              autreId: autreId,
              dernierMessage: dernierMessage,
              estNonLu: estNonLu,
            );
          },
        );
      },
    );
  }

  /// Convertit un champ Firestore (Timestamp ou null) en DateTime.
  DateTime _getTimestamp(QueryDocumentSnapshot doc, String field) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data[field];
    if (ts is Timestamp) return ts.toDate();
    return DateTime(2000);
  }

  /// Construit une tuile de conversation.
  Widget _buildConversationTile({
    required String conversationId,
    required String autreId,
    required String dernierMessage,
    required bool estNonLu,
  }) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserInfos(autreId),
      builder: (context, snapshot) {
        final infos = snapshot.data;
        final prenom = infos?['prenom'] as String? ?? 'Bailleur';
        final nom = infos?['nom'] as String? ?? '';
        final photoUrl = infos?['photoUrl'] as String?;

        return ListTile(
          leading: CircleAvatar(
            radius: 26,
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
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '$prenom $nom',
                  style: TextStyle(
                    fontWeight: estNonLu ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (estNonLu)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          subtitle: Text(
            dernierMessage.isNotEmpty ? dernierMessage : 'Aucun message',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: estNonLu ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversationId: conversationId,
                  destinataireId: autreId,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Récupère les infos d'un utilisateur avec cache.
  Future<Map<String, dynamic>?> _getUserInfos(String uid) async {
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

  // ---------------------------------------------------------------------------
  // ONGLET 2 : SUIVI DES VISITES
  // ---------------------------------------------------------------------------
  Widget _buildVisitesTab() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Utilisateur non connecté'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _visiteService.ecouterVisitesEtudiant(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Erreur : ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final visitesDocs = snapshot.data?.docs ?? [];

        if (visitesDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 72, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Aucune demande de visite',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vous n\'avez pas encore demandé de visite.\nRendez-vous dans les logements pour en faire une !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }

        // Trier les visites : en_attente d'abord, puis par date
        final visites = visitesDocs.map((doc) {
          return VisiteModel.fromFirestore(doc);
        }).toList();

        visites.sort((a, b) {
          if (a.status == 'en_attente' && b.status != 'en_attente') return -1;
          if (a.status != 'en_attente' && b.status == 'en_attente') return 1;
          return b.creeLe.compareTo(a.creeLe);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: visites.length,
          itemBuilder: (context, index) {
            return _buildVisiteCard(visites[index]);
          },
        );
      },
    );
  }

  /// Construit une carte de visite élégante pour l'étudiant.
  Widget _buildVisiteCard(VisiteModel visite) {
    final theme = Theme.of(context);
    final dateFormatee =
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(visite.dateVisite);
    final heureFormatee = DateFormat('HH:mm').format(visite.dateVisite);

    // Configuration du badge de statut
    late Color statusColor;
    late IconData statusIcon;
    late String statusLabel;
    late String statusEmoji;

    switch (visite.status) {
      case 'confirme':
        statusColor = const Color(0xFF2E7D32);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Confirmée ✅';
        statusEmoji = '✅';
        break;
      case 'refuse':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Refusée ❌';
        statusEmoji = '❌';
        break;
      default: // 'en_attente'
        statusColor = Colors.orange;
        statusIcon = Icons.schedule_rounded;
        statusLabel = 'En attente ⏳';
        statusEmoji = '⏳';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: visite.status == 'en_attente'
              ? Colors.orange.withOpacity(0.3)
              : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : titre du logement + badge statut
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visite.logementTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Demande envoyée au bailleur',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de statut
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Date et heure formatées en français
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormatee,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'à $heureFormatee',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Icône de statut visuel
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        statusEmoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Message informatif selon le statut
            const SizedBox(height: 10),
            if (visite.status == 'en_attente')
              _buildInfoChip(
                icon: Icons.info_outline_rounded,
                text: 'En attente de réponse du bailleur',
                color: Colors.orange,
              ),
            if (visite.status == 'confirme')
              _buildInfoChip(
                icon: Icons.check_rounded,
                text: 'Visite confirmée ! Rendez-vous à la date prévue.',
                color: const Color(0xFF2E7D32),
              ),
            if (visite.status == 'refuse')
              _buildInfoChip(
                icon: Icons.info_outline_rounded,
                text: 'Demande refusée par le bailleur.',
                color: Colors.red,
              ),
          ],
        ),
      ),
    );
  }

  /// Petit chip d'information sous la carte.
  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}