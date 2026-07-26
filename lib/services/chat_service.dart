import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Modèle pour un message du chat.
class ChatMessage {
  final String envoyePar;
  final String texte;
  final DateTime? timestamp;

  ChatMessage({
    required this.envoyePar,
    required this.texte,
    this.timestamp,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['timestamp'];
    DateTime? date;
    if (ts is Timestamp) {
      date = ts.toDate();
    }
    // Fallback pour les timestamps null (écriture locale en cours)
    return ChatMessage(
      envoyePar: data['envoyePar'] as String? ?? '',
      texte: data['texte'] as String? ?? '',
      timestamp: date,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'envoyePar': envoyePar,
      'texte': texte,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

/// Service gérant les conversations et messages Firestore.
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Récupère l'UID de l'utilisateur connecté.
  String? get _currentUid => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // GESTION DES CONVERSATIONS
  // ---------------------------------------------------------------------------

  /// Récupère un ID de conversation existant entre deux utilisateurs,
  /// ou en crée un nouveau si aucun n'existe.
  ///
  /// L'ID est généré en combinant les deux UIDs triés alphabétiquement
  /// pour garantir l'unicité et la cohérence (peu importe qui initie).
  /// Note : La création d'une conversation n'envoie PAS de demande de colocation.
  /// L'utilisateur doit cliquer sur "Proposer une équipe" pour cela.
  Future<String> obtenirOuCreerConversation(String autreUid) async {
    final uid1 = _currentUid;
    if (uid1 == null) throw Exception('Utilisateur non connecté');

    // Générer un ID unique basé sur les deux UIDs triés
    final ids = [uid1, autreUid]..sort();
    final conversationId = '${ids[0]}_${ids[1]}';

    // Vérifier si la conversation existe déjà
    final docRef = _firestore.collection('conversations').doc(conversationId);
    final doc = await docRef.get();

    if (!doc.exists) {
      // Créer le document de conversation simple (sans demande de colocation)
      await docRef.set({
        'membres': [uid1, autreUid],
        'dernierMessage': '',
        'misAJourLe': FieldValue.serverTimestamp(),
        'creeLe': FieldValue.serverTimestamp(),
      });
    }

    return conversationId;
  }

  /// Recherche une conversation existante entre deux utilisateurs.
  ///
  /// Retourne l'ID de la conversation si trouvée, sinon null.
  /// La recherche se base sur la présence des deux UIDs dans le champ 'membres'.
  Future<String?> trouverConversationParMembres(
    String uid1,
    String uid2,
  ) async {
    final query = await _firestore
        .collection('conversations')
        .where('membres', whereIn: [
      [uid1, uid2],
      [uid2, uid1]
    ]).limit(1).get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }
    return null;
  }

  /// Propose une équipe de colocation à l'autre membre de la conversation.
  /// Cela déclenche l'affichage du bandeau d'acceptation/refus sur l'écran
  /// de l'autre étudiant.
  Future<void> proposerEquipe(String conversationId) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('Utilisateur non connecté');

    await _firestore.collection('conversations').doc(conversationId).update({
      'demandeStatut': 'en_attente',
      'proposePar': uid,
      'misAJourLe': FieldValue.serverTimestamp(),
    });
  }

  /// Récupère un stream de la liste des conversations pour l'utilisateur connecté.
  /// Note : le tri par date est fait côté Dart (dans l'écran) pour éviter
  /// l'erreur "failed-precondition" due à l'absence d'index composite
  /// (array-contains + orderBy sur misAJourLe).
  Stream<QuerySnapshot> ecouterConversations() {
    final uid = _currentUid;
    if (uid == null) throw Exception('Utilisateur non connecté');

    return _firestore
        .collection('conversations')
        .where('membres', arrayContains: uid)
        .snapshots();
  }

  // ---------------------------------------------------------------------------
  // GESTION DES MESSAGES
  // ---------------------------------------------------------------------------

  /// Envoie un message dans une conversation et met à jour les métadonnées.
  /// Ajoute également les UIDs des membres qui n'ont pas encore lu le message
  /// dans le champ `nonLuPar`.
  Future<void> envoyerMessage({
    required String conversationId,
    required String texte,
  }) async {
    final envoyePar = _currentUid;
    if (envoyePar == null) throw Exception('Utilisateur non connecté');
    if (texte.trim().isEmpty) return;

    final message = ChatMessage(
      envoyePar: envoyePar,
      texte: texte.trim(),
    );

    // Ajouter le message dans la sous-collection
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message.toFirestore());

    // Récupérer les membres pour définir nonLuPar (tous sauf l'expéditeur)
    final doc = await _firestore.collection('conversations').doc(conversationId).get();
    final membres = List<String>.from((doc.data()?['membres'] as List?) ?? []);
    final nonLuPar = membres.where((uid) => uid != envoyePar).toList();

    // Mettre à jour les métadonnées de la conversation
    await _firestore.collection('conversations').doc(conversationId).update({
      'dernierMessage': texte.trim(),
      'misAJourLe': FieldValue.serverTimestamp(),
      'nonLuPar': nonLuPar,
    });
  }

  /// Écoute les messages d'une conversation en temps réel.
  /// Les messages sont triés par timestamp ascendant (du plus vieux au plus récent).
  Stream<QuerySnapshot> ecouterMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Écoute en temps réel le document de la conversation (pour suivre demandeStatut).
  Stream<DocumentSnapshot> ecouterConversation(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots();
  }

  /// Met à jour le statut de la demande de colocation dans la conversation.
  Future<void> mettreAJourDemandeStatut({
    required String conversationId,
    required String statut,
  }) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'demandeStatut': statut,
      'misAJourLe': FieldValue.serverTimestamp(),
    });
  }

  /// Accepte la colocation : met à jour le statut de la conversation à "accepte"
  /// et crée un document dans la collection equipes.
  /// 
  /// Contrairement à l'ancienne version, cette méthode ne touche PAS
  /// directement les documents utilisateurs (users) pour éviter l'erreur
  /// [cloud_firestore/permission-denied]. Seul le document conversation
  /// et la collection equipes sont modifiés.
  Future<void> accepterColocation(String conversationId) async {
    final currentUid = _currentUid;
    if (currentUid == null) throw Exception('Utilisateur non connecté');

    // Récupérer les infos de la conversation
    final doc = await _firestore.collection('conversations').doc(conversationId).get();
    if (!doc.exists) throw Exception('Conversation introuvable');

    final data = doc.data()!;
    final membres = List<String>.from(data['membres'] as List);
    if (membres.length != 2) throw Exception('Conversation invalide');

    // Créer l'équipe dans la collection equipes (ID basé sur les UIDs triés)
    final idsSorted = List<String>.from(membres)..sort();
    final equipeId = 'equipe_${idsSorted[0]}_${idsSorted[1]}';

    final equipeRef = _firestore.collection('equipes').doc(equipeId);
    final equipeDoc = await equipeRef.get();

    if (!equipeDoc.exists) {
      await equipeRef.set({
        'id': equipeId,
        'membres': membres,
        'creeLe': FieldValue.serverTimestamp(),
        'misAJourLe': FieldValue.serverTimestamp(),
      });
    }

    // Mettre à jour le statut de la conversation
    await mettreAJourDemandeStatut(
      conversationId: conversationId,
      statut: 'accepte',
    );

    // Ajouter l'idEquipe sur le document de conversation
    await _firestore.collection('conversations').doc(conversationId).update({
      'idEquipe': equipeId,
    });
  }

  // ---------------------------------------------------------------------------
  // GESTION DES MESSAGES NON LUS
  // ---------------------------------------------------------------------------

  /// Marque une conversation comme lue par l'utilisateur connecté.
  /// Retire l'UID de l'utilisateur du champ `nonLuPar` de la conversation.
  Future<void> marquerCommeLu(String conversationId) async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'nonLuPar': FieldValue.arrayRemove([uid]),
      });
    } catch (_) {
      // Silencieux — le champ peut ne pas exister encore
    }
  }

  /// Stream des conversations où l'utilisateur connecté a des messages non lus
  /// (détecté via le champ `nonLuPar` contenant son UID).
  Stream<QuerySnapshot> ecouterConversationsNonLues() {
    final uid = _currentUid;
    if (uid == null) throw Exception('Utilisateur non connecté');

    return _firestore
        .collection('conversations')
        .where('membres', arrayContains: uid)
        .where('nonLuPar', arrayContains: uid)
        .snapshots();
  }

  // ---------------------------------------------------------------------------
  // UTILITAIRES
  // ---------------------------------------------------------------------------

  /// Récupère les infos de l'utilisateur actuel.
  Future<Map<String, dynamic>?> recupererInfosUtilisateur() async {
    final uid = _currentUid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Retourne l'UID de l'utilisateur connecté (ou null).
  String? get currentUserId => _currentUid;
}