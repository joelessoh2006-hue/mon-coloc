// Page d'inscription progressive pour les étudiants uniquement
// Orchestre : Firebase Auth (étape 1) + collecte des infos → création UserModel → Firestore
// Le rôle est passé en paramètre depuis RoleSelectionScreen
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mon_coloc/services/auth_service.dart';
import 'package:mon_coloc/services/user_service.dart';
import 'package:mon_coloc/screens/auth/register_step1_screen.dart';
import 'package:mon_coloc/screens/auth/register_step2_screen.dart';
import 'package:mon_coloc/screens/auth/register_step3_screen.dart';
import 'package:mon_coloc/screens/home_screen.dart';

class RegisterPage extends StatefulWidget {
  /// Rôle de l'utilisateur : 'etudiant' uniquement ici (bailleur a son propre écran)
  final String role;

  /// Appelé une fois que l'inscription est entièrement terminée.
  final VoidCallback onInscriptionTerminee;

  const RegisterPage({
    super.key,
    required this.role,
    required this.onInscriptionTerminee,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _pageController = PageController();
  final _authService = AuthService();
  final _userService = UserService();

  int _pageCourante = 0;
  bool _enChargement = false;

  // Rôle passé depuis l'extérieur
  String get _role => widget.role;

  // Données communes (étape 1)
  String _nom = '';
  String _prenom = '';
  String _email = '';
  String _motDePasse = '';
  String _telephone = '';
  String _ecoleUniversite = '';
  DateTime? _dateNaissance;
  int? _age;

  // Données spécifiques Étudiant (étape 2)
  double _budgetMaxFCFA = 0;
  List<String> _quartierCible = [];
  StatutLogement _statutLogement = StatutLogement.chercheUnLogement;

  // Données "J'ai déjà un logement" (étape 2)
  String _logementQuartier = '';
  double _logementLoyerTotal = 0;
  double _logementPartColoc = 0;
  String _logementDescription = '';
  List<XFile> _logementPhotosFiles = [];

  // Données étape 3 : Sexe & Préférence de mixité
  Sexe _sexe = Sexe.homme;
  bool _accepteMixite = false;

  // Données étape 3 : Habitudes de vie
  Proprete _proprete = Proprete.propre;
  RythmeDeVie _rythmeDeVie = RythmeDeVie.leveTot;
  bool _fumeur = false;
  StatutAnimaux _statutAnimaux = StatutAnimaux.non;
  String? _typeAnimaux;
  bool _bruitsFortsVolume = false;
  bool _appelsFrequents = false;
  bool _soireesAmis = false;
  bool _besoinSilence = false;
  HoraireRevision _horaireRevision = HoraireRevision.flexible;

  /// Nombre total d'étapes selon le rôle
  int get _nombreEtapes => 3; // Étudiant : toujours 3 étapes

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
  Future<void> _surEtape1({
    required String nom,
    required String prenom,
    required String email,
    required String motDePasse,
    required String telephone,
    required String ecoleUniversite,
    required DateTime? dateNaissance,
    required int? age,
  }) async {
    setState(() {
      _nom = nom;
      _prenom = prenom;
      _email = email;
      _motDePasse = motDePasse;
      _telephone = telephone;
      _ecoleUniversite = ecoleUniversite;
      _dateNaissance = dateNaissance;
      _age = age;
    });

    // Étudiant → va à l'étape 2 (critères de logement)
    _allerPage(1);
  }

  // Étape 2 (Étudiant) → Stocke les critères de logement et va à l'étape 3
  void _surEtape2({
    required double budgetMaxFCFA,
    required List<String> quartierCible,
    required StatutLogement statutLogement,
    String? logementQuartier,
    double? logementLoyerTotal,
    double? logementPartColoc,
    String? logementDescription,
    List<XFile>? logementPhotos,
  }) {
    setState(() {
      _budgetMaxFCFA = budgetMaxFCFA;
      _quartierCible = quartierCible;
      _statutLogement = statutLogement;
      _logementQuartier = logementQuartier ?? '';
      _logementLoyerTotal = logementLoyerTotal ?? 0;
      _logementPartColoc = logementPartColoc ?? 0;
      _logementDescription = logementDescription ?? '';
      _logementPhotosFiles = logementPhotos ?? [];
    });
    _allerPage(2);
  }

  // Étape 3 (Étudiant) → Finalise l'inscription
  Future<void> _surEtape3({
    required Sexe sexe,
    required bool accepteMixite,
    required Proprete proprete,
    required RythmeDeVie rythmeDeVie,
    required bool fumeur,
    required StatutAnimaux statutAnimaux,
    required String? typeAnimaux,
    required bool bruitsFortsVolume,
    required bool appelsFrequents,
    required bool soireesAmis,
    required bool besoinSilence,
    required HoraireRevision horaireRevision,
  }) async {
    setState(() {
      _sexe = sexe;
      _accepteMixite = accepteMixite;
      _proprete = proprete;
      _rythmeDeVie = rythmeDeVie;
      _fumeur = fumeur;
      _statutAnimaux = statutAnimaux;
      _typeAnimaux = typeAnimaux;
      _bruitsFortsVolume = bruitsFortsVolume;
      _appelsFrequents = appelsFrequents;
      _soireesAmis = soireesAmis;
      _besoinSilence = besoinSilence;
      _horaireRevision = horaireRevision;
    });

    await _finaliserInscription();
  }

  /// Compresse et encode une liste d'images en Base64.
  Future<List<String>> _processerPhotosLogement(List<XFile> files) async {
    List<String> base64Images = [];
    for (var file in files) {
      try {
        final bytes = await file.readAsBytes();
        // Note: Une compression plus agressive pourrait être faite ici avec le package 'image'
        // Pour l'instant, on se contente de l'encodage.
        final base64String = base64Encode(bytes);
        base64Images.add('data:image/jpeg;base64,$base64String');
      } catch (e) {
        debugPrint("Erreur d'encodage d'image : $e");
        // On pourrait choisir d'ignorer l'image ou de logger l'erreur.
      }
    }
    return base64Images;
  }

  /// Crée le compte Firebase + Firestore pour l'étudiant
  Future<void> _finaliserInscription() async {
    setState(() => _enChargement = true);

    try {
      // 1. Création du compte Firebase Auth
      final cred = await _authService.creerCompte(
        email: _email,
        motDePasse: _motDePasse,
      );

      final firebaseUser = cred.user;
      if (firebaseUser == null) {
        throw Exception(
          "L'utilisateur Firebase est null après la création du compte.",
        );
      }

      final aDejaUnLogement = _statutLogement == StatutLogement.aDejaUnLogement;

      // Traiter les photos si l'utilisateur a un logement
      final photosEncodees = aDejaUnLogement
          ? await _processerPhotosLogement(_logementPhotosFiles)
          : <String>[];

      // Étudiant : inscription complète avec toutes les données
      final user = UserModel(
        uid: firebaseUser.uid,
        email: _email,
        nom: _nom,
        prenom: _prenom,
        telephone: _telephone,
        ecoleUniversite: _ecoleUniversite,
        role: 'etudiant',
        estVerifie: false,
        budgetMaxFCFA: _budgetMaxFCFA,
        quartierCible: _quartierCible,
        statutLogement: _statutLogement,
        sexe: _sexe,
        accepteMixite: _accepteMixite,
        proprete: _proprete,
        rythmeDeVie: _rythmeDeVie,
        fumeur: _fumeur,
        statutAnimaux: _statutAnimaux,
        typeAnimaux: _typeAnimaux,
        appelsFrequents: _appelsFrequents,
        soireesAmis: _soireesAmis,
        besoinSilence: _besoinSilence,
        horaireRevision: _horaireRevision,
        aDejaUnLogement: aDejaUnLogement,
        logementQuartier: aDejaUnLogement ? _logementQuartier : null,
        logementLoyerTotal: aDejaUnLogement ? _logementLoyerTotal : null,
        logementPartColoc: aDejaUnLogement ? _logementPartColoc : null,
        logementDescription: aDejaUnLogement ? _logementDescription : null,
        logementPhotos: photosEncodees,
        dateNaissance: _dateNaissance,
        age: _age,
      );

      // 2. Sauvegarde des données dans Firestore
      await _userService.sauvegarderUtilisateur(user);

      // 3. Redirection directe vers l'écran d'accueil en cas de SUCCÈS
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => HomeScreen()),
          (Route<dynamic> route) => false,
        );
      }
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
      try {
        final err = e as dynamic;
        messageErreur = err.message ?? err.code ?? err.toString();
        if (messageErreur == 'Error') {
          final errMap = err is Map ? err : null;
          messageErreur =
              errMap?['message'] ?? 'Erreur inconnue côté serveur (code 400)';
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
        Column(
          children: [
            // Barre de progression
            _construireProgressBar(),
            // PageView avec les 3 étapes étudiant
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _pageCourante = page),
                children: [
                  // Étape 1 : RegisterStep1Screen (sans sélection de rôle)
                  RegisterStep1Screen(onSuivant: _surEtape1),

                  // Étape 2 : critères de logement
                  RegisterStep2Screen(
                    onSuivant: _surEtape2,
                    onRetour: () => _allerPage(0),
                    ecoleUniversite: _ecoleUniversite,
                  ),

                  // Étape 3 : habitudes de vie + sexe + mixité
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
        children: List.generate(_nombreEtapes, (index) {
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
