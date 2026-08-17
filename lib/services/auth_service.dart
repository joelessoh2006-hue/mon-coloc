import 'package:firebase_auth/firebase_auth.dart';

/// Service gérant l'authentification Firebase (Email/Mot de passe).
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crée un compte utilisateur avec email et mot de passe.
  /// Retourne le [UserCredential] en cas de succès.
  Future<UserCredential> creerCompte({
    required String email,
    required String motDePasse,
  }) async {
    try {
      return await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: motDePasse,
          )
          .timeout(const Duration(seconds: 12),
              onTimeout: () => throw FirebaseAuthException(
                    code: 'network-request-failed',
                    message: 'Le serveur met trop de temps à répondre.',
                  ));
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Connecte un utilisateur existant.
  Future<UserCredential> connecter({
    required String email,
    required String motDePasse,
  }) async {
    try {
      return await _auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: motDePasse,
          )
          .timeout(const Duration(seconds: 12),
              onTimeout: () => throw FirebaseAuthException(
                    code: 'network-request-failed',
                    message: 'Le serveur met trop de temps à répondre.',
                  ));
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Déconnecte l'utilisateur courant.
  Future<void> deconnecter() async {
    await _auth.signOut();
  }

  /// Retourne l'utilisateur Firebase actuellement connecté (ou null).
  User? get utilisateurActuel => _auth.currentUser;
}