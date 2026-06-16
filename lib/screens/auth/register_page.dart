// Page d'inscription progressive en 3 étapes via PageView
// Orchestre : Firebase Auth (étape 1) + collecte des infos → création UserModel → Firestore

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:mon_coloc/services/auth_service.dart';
import 'package:mon_coloc/services/user_service.dart';
import 'package:mon_coloc/screens/auth/register_step1_screen.dart';
import 'package:mon_coloc/screens/auth/register_step2_screen.dart';
import 'package:mon_coloc/screens/auth/register_step3_screen.dart';

class RegisterPage extends StatefulWidget {
  /// Appelé une fois que l'inscription est entièrement terminée.
  final VoidCallback onInscriptionTerminee;

  const RegisterPage({super.key, required this.onInscriptionTerminee});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _pageController = PageController();
  final _authService = AuthService();
  final _userService = UserService();

  int _pageCourante = 0;
  bool _enChargement = false;

  // Données accumulées sur les 3 étapes
  String _nom = '';
  String _prenom = '';
  String _email = '';
  String _motDePasse = '';
  String _telephone = '';
  String _ecoleUniversite = '';

  double _budgetMaxFCFA = 0;
  List<String> _quartierCible = [];
  StatutLogement _statutLogement = StatutLogement.chercheUnLogement;

  Proprete _proprete = Proprete.propre;
  RythmeDeVie _rythmeDeVie = RythmeDeVie.leveTot;
  bool _fumeur = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _allerPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // Étape 1 → Stocke les infos et va à l'étape 2
  void _surEtape1({
    required String nom,
    required String prenom,
    required String email,
    required String motDePasse,
    required String telephone,
    required String ecoleUniversite,
  }) {
    setState(() {
      _nom = nom;
      _prenom = prenom;
      _email = email;
      _motDePasse = motDePasse;
      _telephone = telephone;
      _ecoleUniversite = ecoleUniversite;
    });
    _allerPage(1);
  }

  // Étape 2 → Stocke les critères de logement et va à l'étape 3
  void _surEtape2({
    required double budgetMaxFCFA,
    required List<String> quartierCible,
    required StatutLogement statutLogement,
  }) {
    setState(() {
      _budgetMaxFCFA = budgetMaxFCFA;
      _quartierCible = quartierCible;
      _statutLogement = statutLogement;
    });
    _allerPage(2);
  }

  // Étape 3 → Finalise l'inscription : Firebase Auth + Firestore
  Future<void> _surEtape3({
    required Proprete proprete,
    required RythmeDeVie rythmeDeVie,
    required bool fumeur,
  }) async {
    setState(() {
      _proprete = proprete;
      _rythmeDeVie = rythmeDeVie;
      _fumeur = fumeur;
      _enChargement = true;
    });

    try {
      // 1. Création du compte Firebase Auth
      final cred = await _authService.creerCompte(
        email: _email,
        motDePasse: _motDePasse,
      );

      final firebaseUser = cred.user;
      if (firebaseUser == null) {
        throw Exception("L'utilisateur Firebase est null après la création du compte.");
      }

      // 2. Construction du UserModel complet
      final user = UserModel(
        uid: firebaseUser.uid,
        email: _email,
        nom: _nom,
        prenom: _prenom,
        telephone: _telephone,
        ecoleUniversite: _ecoleUniversite,
        budgetMaxFCFA: _budgetMaxFCFA,
        quartierCible: _quartierCible,
        statutLogement: _statutLogement,
        proprete: _proprete,
        rythmeDeVie: _rythmeDeVie,
        fumeur: _fumeur,
      );

      // 3. Sauvegarde dans Firestore collection 'users'
      await _userService.sauvegarderUtilisateur(user);

      if (!mounted) return;

      // 4. Succès → retour à l'appelant
      widget.onInscriptionTerminee();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _enChargement = false);

      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Cet email est déjà utilisé.';
          break;
        case 'weak-password':
          message = 'Le mot de passe est trop faible.';
          break;
        case 'invalid-email':
          message = "L'adresse email est invalide.";
          break;
        default:
          message = 'Erreur : ${e.message ?? e.code}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e, stackTrace) {
      if (!mounted) return;
      setState(() => _enChargement = false);

      String messageErreur;
      // Sur le Web, l'erreur JS est un objet Error avec des propriétés cachées
      try {
        // Tentative d'extraction des détails de l'erreur JS
        final err = e as dynamic;
        messageErreur = err.message ?? err.code ?? err.toString();
        if (messageErreur == 'Error') {
          // Essaye de récupérer le message de la réponse HTTP
          final errMap = err is Map ? err : null;
          messageErreur = errMap?['message'] ?? 'Erreur inconnue côté serveur (code 400)';
        }
      } catch (_) {
        messageErreur = e.toString();
      }

      debugPrint('Erreur inscription (détaillée) : $e\n$stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $messageErreur'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Indicateur de progression horizontal
        Column(
          children: [
            // Barre de progression
            _construireProgressBar(),
            // PageView avec les 3 étapes
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) =>
                    setState(() => _pageCourante = page),
                children: [
                  RegisterStep1Screen(onSuivant: _surEtape1),
                  RegisterStep2Screen(
                    onSuivant: _surEtape2,
                    onRetour: () => _allerPage(0),
                  ),
                  RegisterStep3Screen(
                    onTerminer: _surEtape3,
                    onRetour: () => _allerPage(1),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Indicateur de chargement (overlay)
        if (_enChargement)
          Container(
            color: Colors.black26,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Création de votre compte…',
                        style: TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _construireProgressBar() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(top: 48, left: 24, right: 24, bottom: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: List.generate(3, (index) {
          final bool estComplete = index < _pageCourante;
          final bool estActive = index == _pageCourante;

          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: estComplete || estActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}