import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/screens/chat_screen.dart';
import 'package:mon_coloc/services/chat_service.dart';

/// Écran de la boîte de réception du bailleur.
/// Liste toutes les conversations avec les étudiants.
class BailleurInboxScreen extends StatefulWidget {
  const BailleurInboxScreen({super.key});

  @override
  State<BailleurInboxScreen> createState() => _BailleurInboxScreenState();
}

class _BailleurInboxScreenState extends State<BailleurInboxScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cache les infos des utilisateurs (prénom, nom, photo)
  final Map<String, Map<String, dynamic>?> _cacheInfos = {};

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Utilisateur non connecté'));
    }

    return Scaffold(
      appBar: null,
      body: StreamBuilder<QuerySnapshot>(
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
                    'Les messages des étudiants apparaîtront ici',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
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
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
            itemBuilder: (context, index) {
              final conv = triees[index];
              final data = conv.data() as Map<String, dynamic>;
              final membres = List<String>.from(data['membres'] as List? ?? []);
              final dernierMessage = data['dernierMessage'] as String? ?? '';
              final nonLuPar = List<String>.from(data['nonLuPar'] as List? ?? []);
              final estNonLu = nonLuPar.contains(uid);

              // Déterminer l'autre participant (pas le bailleur connecté)
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
      ),
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
        final prenom = infos?['prenom'] as String? ?? 'Étudiant';
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
}