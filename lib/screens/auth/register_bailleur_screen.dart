// Écran d'inscription dédié aux bailleurs
// Demande : Nom, Prénom, Adresse email, Mot de passe, Numéro de téléphone
// PAS de champ École/Université ni de budget
// Après validation → redirige vers RegisterBailleurDocsScreen

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:mon_coloc/services/auth_service.dart';
import 'package:mon_coloc/services/user_service.dart';
import 'package:mon_coloc/screens/auth/register_bailleur_docs_screen.dart';

class RegisterBailleurScreen extends StatefulWidget {
  final VoidCallback onInscriptionTerminee;

  const RegisterBailleurScreen({super.key, required this.onInscriptionTerminee});

  @override
  State<RegisterBailleurScreen> createState() => _RegisterBailleurScreenState();
}

class _RegisterBailleurScreenState extends State<RegisterBailleurScreen> {
  final _cleForm = GlobalKey<FormState>();
  final _authService = AuthService();
  final _userService = UserService();

  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mdpCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  bool _mdpVisible = false;
  bool _enChargement = false;

  // Données conservées pour la finalisation après l'upload des documents
  String _nom = '';
  String _prenom = '';
  String _email = '';
  String _motDePasse = '';
  String _telephone = '';

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  void _soumettre() {
    if (!_cleForm.currentState!.validate()) return;

    setState(() {
      _nom = _nomCtrl.text.trim();
      _prenom = _prenomCtrl.text.trim();
      _email = _emailCtrl.text.trim();
      _motDePasse = _mdpCtrl.text;
      _telephone = _telCtrl.text.trim();
    });

    // Rediriger vers l'écran de documents
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterBailleurDocsScreen(
          onFinaliser: _finaliserInscription,
          onRetour: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

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
            "L'utilisateur Firebase est null après la création du compte.");
      }

      // 2. Sauvegarde dans Firestore
      final user = UserModel(
        uid: firebaseUser.uid,
        email: _email,
        nom: _nom,
        prenom: _prenom,
        telephone: _telephone,
        ecoleUniversite: '', // Pas d'école pour le bailleur
        role: 'bailleur',
        estVerifie: false,
        // Valeurs par défaut pour les champs étudiant (non utilisés)
        budgetMaxFCFA: 0,
        quartierCible: [],
        statutLogement: StatutLogement.chercheUnLogement,
        sexe: Sexe.homme,
        accepteMixite: false,
        proprete: Proprete.propre,
        rythmeDeVie: RythmeDeVie.leveTot,
        fumeur: false,
        statutAnimaux: StatutAnimaux.non,
        typeAnimaux: null,
        bruitsFortsVolume: false,
        appelsFrequents: false,
        soireesAmis: false,
        besoinSilence: false,
        horaireRevision: HoraireRevision.flexible,
      );

      await _userService.sauvegarderUtilisateur(user);

      if (!mounted) return;

      // 3. Retour à l'écran d'accueil (pop jusqu'à la racine)
      Navigator.of(context).popUntil((route) => route.isFirst);

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

      _afficherErreur(message);
    } catch (e, stackTrace) {
      if (!mounted) return;
      setState(() => _enChargement = false);

      debugPrint('Erreur inscription bailleur : $e\n$stackTrace');
      _afficherErreur('Une erreur est survenue. Veuillez réessayer.');
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _cleForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bouton retour
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 24),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.surfaceContainerLow,
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _construireEnTete(theme),
                    const SizedBox(height: 32),

                    // Nom
                    _champTexte(
                      controleur: _nomCtrl,
                      label: 'Nom',
                      icone: Icons.person_outline,
                      validateur: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Veuillez entrer votre nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Prénom
                    _champTexte(
                      controleur: _prenomCtrl,
                      label: 'Prénom',
                      icone: Icons.badge_outlined,
                      validateur: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Veuillez entrer votre prénom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    _champTexte(
                      controleur: _emailCtrl,
                      label: 'Adresse email',
                      icone: Icons.email_outlined,
                      typeClavier: TextInputType.emailAddress,
                      validateur: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Veuillez entrer votre adresse email';
                        }
                        if (!RegExp(r'^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,}$')
                            .hasMatch(val.trim())) {
                          return 'Adresse email invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Mot de passe
                    TextFormField(
                      controller: _mdpCtrl,
                      obscureText: !_mdpVisible,
                      decoration: _decorationChamp(
                        label: 'Mot de passe',
                        icone: Icons.lock_outline,
                        theme: theme,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _mdpVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _mdpVisible = !_mdpVisible),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Veuillez entrer un mot de passe';
                        }
                        if (val.length < 6) {
                          return 'Le mot de passe doit contenir au moins 6 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Téléphone +225
                    TextFormField(
                      controller: _telCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _decorationChamp(
                        label: 'Numéro de téléphone',
                        icone: Icons.phone_outlined,
                        theme: theme,
                        prefixText: '+225 ',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Veuillez entrer votre numéro de téléphone';
                        }
                        if (val.trim().length < 8) {
                          return 'Numéro trop court (min. 8 chiffres)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 36),

                    // Bouton Suivant
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _soumettre,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Suivant',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Information
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Après cette étape, vous devrez fournir '
                                'vos documents justificatifs.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF15803D),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
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
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets internes
  // ---------------------------------------------------------------------------

  Widget _construireEnTete(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.home_work_rounded,
            color: Color(0xFF059669),
            size: 26,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Inscription bailleur',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Créez votre compte pour proposer des logements',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Profil Bailleur',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF059669),
            ),
          ),
        ),
      ],
    );
  }

  Widget _champTexte({
    required TextEditingController controleur,
    required String label,
    required IconData icone,
    TextInputType typeClavier = TextInputType.text,
    String? Function(String?)? validateur,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controleur,
      keyboardType: typeClavier,
      decoration: _decorationChamp(label: label, icone: icone, theme: theme),
      validator: validateur,
    );
  }

  InputDecoration _decorationChamp({
    required String label,
    required IconData icone,
    required ThemeData theme,
    Widget? suffixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant,
        fontSize: 14,
      ),
      prefixIcon: Icon(icone, color: theme.colorScheme.outline, size: 20),
      prefixText: prefixText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}