import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mon_coloc/models/user_model.dart';

/// Service gérant les opérations Firestore pour la collection 'users'
/// et le téléversement de fichiers vers Firebase Storage.
class UserService {
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');
  final CollectionReference _signalementsCollection = FirebaseFirestore.instance
      .collection('signalements');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Sauvegarde ou met à jour un utilisateur dans Firestore.
  Future<void> sauvegarderUtilisateur(UserModel user) async {
    await _usersCollection.doc(user.uid).set(user.toFirestore());
  }

  /// Met à jour partiellement un utilisateur dans Firestore.
  Future<void> mettreAJourPartiel({
    required String uid,
    required Map<String, dynamic> donnees,
  }) async {
    await _usersCollection.doc(uid).update(donnees);
  }

  /// Récupère un utilisateur par son UID.
  Future<UserModel?> recupererUtilisateur(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Écoute en temps réel les changements d'un utilisateur.
  Stream<UserModel?> ecouterUtilisateur(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  /// Signale un élément (logement, utilisateur, etc.) en créant un document
  /// dans la collection 'signalements' - ANCIEN FORMAT (compatible)
  Future<void> signalerElement({
    required String type,
    required String idElement,
    required String motif,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await _signalementsCollection.add({
      'type': type,
      'idElement': idElement,
      'motif': motif,
      'idUtilisateur': userId,
      'dateSignalement': FieldValue.serverTimestamp(),
    });
  }

  /// Signale un utilisateur (Étudiant ou Bailleur) avec type explicite.
  /// Types: 'bailleur_vers_etudiant', 'etudiant_vers_bailleur', 'etudiant_vers_etudiant'
  /// Optionnel: conversationId si le signalement est lié à une conversation
  Future<void> signalerUtilisateur({
    required String typeSignalement,
    required String idUtilisateurSignale,
    required String nomUtilisateurSignale,
    required String motif,
    required String description,
    String? conversationId,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('Utilisateur non authentifié');
    }

    final userData = await _usersCollection.doc(userId).get();
    final auteurNom = userData.exists
        ? '${(userData.data() as Map)['prenom'] ?? ''} ${(userData.data() as Map)['nom'] ?? ''}'
              .trim()
        : 'Utilisateur';

    final reportData = {
      'type': 'utilisateur',
      'typeSignalement': typeSignalement,
      'cibleId': idUtilisateurSignale,
      'cibleNom': nomUtilisateurSignale,
      'auteurId': userId,
      'auteurNom': auteurNom,
      'motif': motif,
      'description': description,
      'dateCreation': FieldValue.serverTimestamp(),
      'dateSignalement': FieldValue.serverTimestamp(),
      'statut': 'en_attente',
    };

    // Ajouter conversationId si fourni
    if (conversationId != null && conversationId.isNotEmpty) {
      reportData['conversationId'] = conversationId;
    }

    await _signalementsCollection.add(reportData);
  }

  /// Signale un logement avec détails complets.
  Future<void> signalerLogement({
    required String logementId,
    required String nomBailleur,
    required String motif,
    required String description,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('Utilisateur non authentifié');
    }

    final userData = await _usersCollection.doc(userId).get();
    final auteurNom = userData.exists
        ? '${(userData.data() as Map)['prenom'] ?? ''} ${(userData.data() as Map)['nom'] ?? ''}'
              .trim()
        : 'Utilisateur';

    await _signalementsCollection.add({
      'type': 'logement',
      'typeSignalement': 'logement',
      'cibleId': logementId,
      'cibleNom': 'Logement',
      'auteurId': userId,
      'auteurNom': auteurNom,
      'motif': motif,
      'description': description,
      'dateCreation': FieldValue.serverTimestamp(),
      'dateSignalement': FieldValue.serverTimestamp(),
      'statut': 'en_attente',
    });
  }

  /// Encode une image de profil en Base64 et retourne une Data URL.
  Future<String> televerserPhotoProfil({
    required String uid,
    required XFile imageFile,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final base64String = base64Encode(bytes);
    // Le uid n'est plus utilisé ici, mais conservé pour la compatibilité de l'appel.
    return 'data:image/jpeg;base64,$base64String';
  }

  /// Encode un document justificatif en Base64 et retourne une Data URL.
  Future<String> televerserJustificatif({
    required String uid,
    required XFile docFile,
  }) async {
    final bytes = await docFile.readAsBytes();
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  /// Téléverse des données d'image (bytes) pour la photo de profil (Flutter Web).
  Future<String> televerserPhotoProfilBytes({
    required String uid,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref().child('photos_profil/$uid.jpg');
    final uploadTask = ref.putData(bytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Encode des données d'image (bytes) pour un justificatif et retourne une Data URL.
  Future<String> televerserJustificatifBytes({
    required String uid,
    required Uint8List bytes,
  }) async {
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  /// Encode une photo de logement en Base64 et retourne une Data URL.
  Future<String> televerserPhotoLogement({
    required String uid,
    required XFile imageFile,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  /// Encode une photo de logement en Base64 et retourne une Data URL.
  Future<String> televerserPhotoLogementBytes({
    required String uid,
    required Uint8List bytes,
  }) async {
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  /// Encode un document justificatif pour un bailleur en une chaîne de données Base64.
  /// Retourne une Data URL (ex: "data:image/jpeg;base64,...").
  Future<String> televerserJustificatifBailleur({
    required String uid,
    required String nom,
    Uint8List? bytes,
    // Ajout d'une option pour compresser les images avant encodage
    bool compresserImage = false,
    String? chemin,
  }) async {
    try {
      Uint8List? fileBytes = bytes;

      // Si les bytes ne sont pas fournis mais un chemin l'est, lire le fichier.
      if (fileBytes == null && chemin != null && chemin.isNotEmpty) {
        fileBytes = await File(chemin).readAsBytes();
      }

      if (fileBytes != null && fileBytes.isNotEmpty) {
        final mimeType = nom.toLowerCase().endsWith('.pdf')
            ? 'application/pdf'
            : 'image/jpeg';

        // Si c'est une image et que la compression est demandée
        if (mimeType == 'image/jpeg' && compresserImage) {
          try {
            // Utiliser le package 'image' pour décoder, redimensionner et compresser
            final image = img.decodeImage(fileBytes);
            if (image != null) {
              img.Image resized = image;
              // Redimensionner si l'image est trop grande
              if (image.width > 1024 || image.height > 1024) {
                resized = img.copyResize(image, width: 1024);
              }
              // Compresser en JPEG avec une qualité réduite
              final compressedBytes = img.encodeJpg(resized, quality: 75);
              final base64String = base64Encode(compressedBytes);
              return 'data:$mimeType;base64,$base64String';
            }
          } catch (e) {
            print('Erreur de compression d\'image, fallback sur l\'original: $e');
          }
        }

        return 'data:$mimeType;base64,${base64Encode(fileBytes)}';
      }
      return '';
    } catch (e) {
      print('Erreur conversion Base64 pour justificatif bailleur : $e');
      return '';
    }
  }
}
