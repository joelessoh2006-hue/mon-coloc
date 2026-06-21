import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/services/chat_service.dart';

/// Écran de chat en temps réel entre deux utilisateurs.
///
/// Prend en paramètres :
/// - [conversationId] : optionnel, si déjà connu
/// - [destinataireId] : UID de la personne avec qui on discute (obligatoire)
/// - [messageInitial] : message pré-rempli optionnel à injecter dans le champ de texte
class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String destinataireId;
  final String? messageInitial;

  const ChatScreen({
    super.key,
    this.conversationId,
    required this.destinataireId,
    this.messageInitial,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ID de la conversation (résolu ou passé en paramètre)
  String? _conversationId;

  /// Infos du destinataire (nom, photo)
  Map<String, dynamic>? _destinataireInfos;

  /// Chargement en cours
  bool _chargement = true;

  /// Erreur éventuelle
  String? _erreur;

  // ---------------------------------------------------------------------------
  // Champs colocation / demande d'équipe
  // ---------------------------------------------------------------------------

  /// Écoute en temps réel du document conversation
  StreamSubscription<DocumentSnapshot>? _conversationSubscription;

  /// Statut de la demande d'équipe (en_attente, accepte, refuse, ou null)
  String? _demandeStatut;

  /// UID de celui qui a proposé l'équipe
  String? _proposePar;

  /// Prénom de l'expéditeur de la proposition (pour la bannière)
  String? _proposeParPrenom;

  /// Si l'utilisateur connecté est celui qui a proposé
  bool get _estProposeur =>
      _auth.currentUser != null && _proposePar == _auth.currentUser!.uid;

  /// Flag local : l'utilisateur a refusé de proposer la colocation
  bool _aRefuseProposition = false;

  @override
  void initState() {
    super.initState();
    // Si un messageInitial est fourni, l'injecter dans le champ de texte
    if (widget.messageInitial != null && widget.messageInitial!.isNotEmpty) {
      _textController.text = widget.messageInitial!;
    }
    _initialiserChat();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _conversationSubscription?.cancel();
    super.dispose();
  }

  /// Initialise la conversation et charge les infos du destinataire.
  Future<void> _initialiserChat() async {
    try {
      // Charger les infos du destinataire
      final destinataireDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.destinataireId)
          .get();

      if (destinataireDoc.exists && mounted) {
        setState(() {
          _destinataireInfos = destinataireDoc.data();
        });
      }

      // Résoudre ou créer la conversation
      String conversationId;
      if (widget.conversationId != null) {
        conversationId = widget.conversationId!;
      } else {
        conversationId =
            await _chatService.obtenirOuCreerConversation(widget.destinataireId);
      }

      if (mounted) {
        setState(() {
          _conversationId = conversationId;
          _chargement = false;
        });

        // Marquer la conversation comme lue
        _chatService.marquerCommeLu(conversationId);

        // Commencer à écouter le document de la conversation
        _ecouterConversation(conversationId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erreur = 'Impossible de charger la conversation : $e';
          _chargement = false;
        });
      }
    }
  }

  /// Écoute en temps réel le document de la conversation pour demandeStatut.
  void _ecouterConversation(String conversationId) {
    _conversationSubscription?.cancel();
    _conversationSubscription =
        _chatService.ecouterConversation(conversationId).listen((doc) {
      if (!doc.exists || !mounted) return;
      final data = doc.data() as Map<String, dynamic>;
      final statut = data['demandeStatut'] as String?;
      final proposePar = data['proposePar'] as String?;

      setState(() {
        _demandeStatut = statut;
        _proposePar = proposePar;
      });

      // Si on a un proposePar et qu'il est différent du current user,
      // charger son prénom
      if (proposePar != null &&
          proposePar != _auth.currentUser?.uid &&
          _proposeParPrenom == null) {
        _chargerPrenomProposePar(proposePar);
      }
    });
  }

  /// Charge le prénom de l'utilisateur qui a proposé l'équipe.
  Future<void> _chargerPrenomProposePar(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _proposeParPrenom = doc.data()?['prenom'] as String?;
        });
      }
    } catch (_) {
      // Silencieux
    }
  }

  /// Propose une équipe de colocation à l'autre personne.
  /// Prénom de l'utilisateur connecté (mis en cache pour le message automatique)
  String? _monPrenom;

  Future<void> _proposerEquipe() async {
    if (_conversationId == null) return;

    try {
      // Envoyer un message automatique dans le chat
      if (_monPrenom == null) {
        final monDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .get();
        _monPrenom = monDoc.data()?['prenom'] as String? ?? 'Un étudiant';
      }

      await _chatService.envoyerMessage(
        conversationId: _conversationId!,
        texte: 'Bonjour, je souhaiterais qu\'on soit colocataires !',
      );

      await _chatService.proposerEquipe(_conversationId!);
      // Le stream Firestore mettra automatiquement à jour l'interface
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande d\'équipe envoyée ! 🤝'),
            backgroundColor: Color(0xFF1565C0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  /// Envoie un message.
  Future<void> _envoyerMessage() async {
    final texte = _textController.text.trim();
    if (texte.isEmpty || _conversationId == null) return;

    setState(() {
      _textController.clear();
    });

    try {
      await _chatService.envoyerMessage(
        conversationId: _conversationId!,
        texte: texte,
      );

      // Scroll vers le bas après envoi
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Scroll la liste des messages vers le bas.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // AFFICHAGE DU BOUTON "PROPOSER UNE ÉQUIPE"
  // ---------------------------------------------------------------------------

  /// Retourne true si le bouton "Proposer une équipe" doit être affiché
  bool get _peutProposerEquipe {
    // Pas de proposition si aucune conversation chargée
    if (_conversationId == null) return false;
    // Pas de proposition si l'utilisateur n'est pas connecté
    if (_auth.currentUser == null) return false;
    // Pas de proposition s'il y a déjà une demande en attente
    if (_demandeStatut == 'en_attente') return false;
    // Pas de proposition si déjà accepté
    if (_demandeStatut == 'accepte') return false;
    // Pas de proposition si refusé (on laisse l'utilisateur reproposer)
    // Peut être proposé si pas de statut (null) ou refusé
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prenom = _destinataireInfos?['prenom'] as String? ?? 'Chat';
    final nom = _destinataireInfos?['nom'] as String? ?? '';
    final photoUrl = _destinataireInfos?['photoUrl'] as String?;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            // Avatar du destinataire
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Nom du destinataire
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$prenom $nom',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'En ligne',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Si la demande est acceptée, montrer une icône de validation
          if (_demandeStatut == 'accepte')
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2E7D32),
              size: 28,
            ),
        ],
      ),
      body: _construireCorps(theme),
    );
  }

  /// Construit le corps de l'écran selon l'état.
  Widget _construireCorps(ThemeData theme) {
    if (_chargement) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Chargement de la conversation…',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_erreur != null) {
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
                _erreur!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.red),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _chargement = true;
                    _erreur = null;
                  });
                  _initialiserChat();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_conversationId == null) {
      return const Center(
        child: Text(
          'Conversation introuvable',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        // Bannière de demande d'équipe (si applicable)
        _buildColocationBanner(),

        // Zone des messages
        Expanded(
          child: _construireListeMessages(theme),
        ),

        // Zone de saisie
        _construireZoneSaisie(theme),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BANNIÈRE DE DEMANDE D'ÉQUIPE
  // ---------------------------------------------------------------------------

  /// Construit la bannière d'état de la demande d'équipe.
  Widget _buildColocationBanner() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final statut = _demandeStatut;

    // --- Aucune demande en cours : bandeau de proposition ---
    if (statut == null) {
      // Si l'utilisateur a déjà refusé de proposer, on cache
      if (_aRefuseProposition) return const SizedBox.shrink();
      // Si l'utilisateur n'est pas connecté, on cache
      if (currentUser.uid.isEmpty) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF9800).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.handshake_rounded,
                    size: 24, color: Color(0xFFE65100)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Voulez-vous proposer une colocation à cet étudiant ?',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4E342E),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _proposerEquipe,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Oui'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _aRefuseProposition = true);
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Non'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.brown.shade600,
                      side: BorderSide(color: Colors.brown.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // --- STATUT accepté : les deux membres voient le message de confirmation ---
    if (statut == 'accepte') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Text(
              '🤝',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Vous formez officiellement une équipe de colocation !',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E7D32),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // --- STATUT refusé ---
    if (statut == 'refuse') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Text(
              '❌',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Demande d\'équipe déclinée.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade700,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // --- STATUT en_attente ---
    // L'expéditeur (proposePar) ne voit pas la bannière d'acceptation
    // (c'est lui qui a proposé)
    if (_proposePar == currentUser.uid) {
      return const SizedBox.shrink();
    }

    // Le destinataire voit la bannière avec les boutons Accepter / Décliner
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE3F2FD),
            const Color(0xFFF3E5F5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message
          Row(
            children: [
              const Icon(Icons.handshake_rounded,
                  size: 24, color: Color(0xFF1565C0)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _proposeParPrenom != null
                      ? '$_proposeParPrenom vous propose de former une équipe de colocation.'
                      : "Un étudiant vous propose de former une équipe de colocation.",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _accepterColocation,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Accepter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _declinerColocation,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Décliner'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Accepte la demande d'équipe.
  Future<void> _accepterColocation() async {
    if (_conversationId == null) return;

    try {
      await _chatService.accepterColocation(_conversationId!);
      // Le stream Firestore mettra automatiquement à jour l'interface
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande d\'équipe acceptée ! 🎉'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  /// Décline la demande d'équipe.
  Future<void> _declinerColocation() async {
    if (_conversationId == null) return;

    try {
      await _chatService.mettreAJourDemandeStatut(
        conversationId: _conversationId!,
        statut: 'refuse',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande d\'équipe déclinée.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  // ---------------------------------------------------------------------------
  // MESSAGES
  // ---------------------------------------------------------------------------

  /// Construit la liste des messages avec StreamBuilder.
  Widget _construireListeMessages(ThemeData theme) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Utilisateur non connecté'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.ecouterMessages(_conversationId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Erreur de chargement des messages : ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final messages = snapshot.data?.docs ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Aucun message pour le moment.\nEnvoyez le premier message !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        }

        // Scroll vers le bas au premier chargement
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
            );
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message =
                ChatMessage.fromFirestore(messages[index]);
            final estMoi = message.envoyePar == currentUser.uid;

            return _buildChatBubble(
              message: message,
              estMoi: estMoi,
              theme: theme,
            );
          },
        );
      },
    );
  }

  /// Construit une bulle de chat individuelle.
  Widget _buildChatBubble({
    required ChatMessage message,
    required bool estMoi,
    required ThemeData theme,
  }) {
    final heure = message.timestamp != null
        ? '${message.timestamp!.hour.toString().padLeft(2, '0')}:${message.timestamp!.minute.toString().padLeft(2, '0')}'
        : '…';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            estMoi ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Espace pour aligner les bulles
          if (estMoi) const SizedBox(width: 60),

          // Bulle de message
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: estMoi
                    ? theme.colorScheme.primary
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(
                    estMoi ? 18 : 4,
                  ),
                  bottomRight: Radius.circular(
                    estMoi ? 4 : 18,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: estMoi
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Texte du message
                  Text(
                    message.texte,
                    style: TextStyle(
                      fontSize: 15,
                      color: estMoi ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Timestamp
                  Text(
                    heure,
                    style: TextStyle(
                      fontSize: 11,
                      color: estMoi
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!estMoi) const SizedBox(width: 60),
        ],
      ),
    );
  }

  /// Construit la zone de saisie en bas de l'écran.
  Widget _construireZoneSaisie(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Champ de texte
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  maxLines: 4,
                  minLines: 1,
                  onSubmitted: (_) => _envoyerMessage(),
                  decoration: InputDecoration(
                    hintText: 'Écrivez un message…',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Bouton d'envoi
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _envoyerMessage,
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                splashRadius: 24,
                tooltip: 'Envoyer',
              ),
            ),
          ],
        ),
      ),
    );
  }
}