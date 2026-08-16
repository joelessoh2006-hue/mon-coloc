import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mon_coloc/utils/image_utils.dart';
import 'package:mon_coloc/models/user_model.dart';

/// Service gérant les opérations Firestore pour la collection 'users'
/// et le téléversement de fichiers vers Firebase Storage.
class UserService {
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');
  final CollectionReference _signalementsCollection = FirebaseFirestore.instance
      .collection('signalements');
  // FirebaseStorage n'est plus utilisé pour le téléversement direct d'images/documents
  // final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Helper pour encoder des octets en Data URL, avec compression d'image optionnelle.
  Future<String> _encodeBytesToDataUrl({
    required Uint8List bytes,
    required String fileName,
    bool compressImage = false,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    if (extension == 'pdf') {
      return 'data:application/pdf;base64,${base64Encode(bytes)}';
    } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      if (compressImage) {
        return ImageUtils.compressAndEncodeBase64(bytes);
      } else {
        return 'data:image/$extension;base64,${base64Encode(bytes)}';
      }
    } else {
      // Fallback pour les types inconnus, traiter comme binaire
      return 'data:application/octet-stream;base64,${base64Encode(bytes)}';
    }
  }

  /// Sauvegarde ou met à jour un utilisateur dans Firestore.
  Future<void> sauvegarderUtilisateur(UserModel user) async {
    final docRef = _usersCollection.doc(user.uid);
    final doc = await docRef.get();
    final data = user.toFirestore();

    if (!doc.exists) {
      // Si le document n'existe pas, c'est une création. On ajoute la date.
      data['dateInscription'] = FieldValue.serverTimestamp();
      // On définit un statut initial pour la modération (ex: pour les bailleurs)
      data['status'] = 'en_attente';
    }

    await docRef.set(data, SetOptions(merge: true));
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

  /// Récupère le DocumentSnapshot d'un utilisateur par son UID.
  Future<DocumentSnapshot?> recupererUtilisateurDoc(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return doc;
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

  /// Téléverse un justificatif étudiant en le convertissant en Data URL Base64.
  Future<String> televerserJustificatifEtudiant({
    required String uid,
    required PlatformFile file,
    required String nomChamp,
  }) async {
    if (file.bytes == null) {
      throw Exception("Les octets du fichier sont nuls.");
    }
    return _encodeBytesToDataUrl(
      bytes: file.bytes!,
      fileName: file.name,
      compressImage: true, // Compression pour les images justificatives
    );
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

  /// Encode la photo de profil en chaîne Data URL Base64 (compressée)
  Future<String> televerserPhotoProfilBytes({
    required String uid,
    required Uint8List bytes,
  }) async {
    return _encodeBytesToDataUrl(
      bytes: bytes,
      fileName: 'profile_photo.jpg',
      compressImage: true,
    );
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
    return _encodeBytesToDataUrl(
      bytes: bytes,
      fileName: 'logement_photo.jpg', // Nom générique pour l'extension
      compressImage: true,
    );
  }

  /// Encode un document justificatif pour un bailleur en une chaîne de données Base64.
  /// Retourne une Data URL (ex: "data:image/jpeg;base64,...").
  Future<String> televerserJustificatifBailleur({
    required String uid,
    required String nom,
    Uint8List? bytes,
    bool compresserImage = false,
  }) async {
    if (bytes == null || bytes.isEmpty) return '';
    return _encodeBytesToDataUrl(
      bytes: bytes,
      fileName: nom,
      compressImage: compresserImage,
    );
  }
}
