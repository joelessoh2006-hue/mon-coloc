// Écran de connexion complet
// Point d'entrée de l'application quand aucun utilisateur n'est connecté

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/services/auth_service.dart';
import 'package:mon_coloc/screens/auth/role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  /// Appelé après une connexion réussie
  final VoidCallback onConnexionReussie;

  const LoginScreen({super.key, required this.onConnexionReussie});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cleForm = GlobalKey<FormState>();
  final _authService = AuthService();

  final _emailCtrl = TextEditingController();
  final _mdpCtrl = TextEditingController();

  bool _mdpVisible = false;
  bool _enChargement = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
    if (!_cleForm.currentState!.validate()) return;

    setState(() => _enChargement = true);

    try {
      await _authService.connecter(
        email: _emailCtrl.text.trim(),
        motDePasse: _mdpCtrl.text,
      );

      if (!mounted) return;
      widget.onConnexionReussie();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _enChargement = false);

      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Aucun compte trouvé avec cet email.';
          break;
        case 'wrong-password':
          message = 'Mot de passe incorrect.';
          break;
        case 'invalid-credential':
          message = 'Email ou mot de passe incorrect.';
          break;
        case 'invalid-email':
          message = "L'adresse email est invalide.";
          break;
        case 'user-disabled':
          message = 'Ce compte a été désactivé.';
          break;
        case 'too-many-requests':
          message = 'Trop de tentatives. Veuillez réessayer plus tard.';
          break;
        default:
          message = 'Erreur : ${e.message ?? e.code}';
      }

      _afficherErreur(message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enChargement = false);
      _afficherErreur('Une erreur est survenue. Veuillez réessayer.');
      debugPrint('Erreur connexion : $e');
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

  void _allerInscription() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoleSelectionScreen(
          onInscriptionTerminee: widget.onConnexionReussie,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _cleForm,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo / Icône
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        Icons.home_work_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Titre
                  Center(
                    child: Text(
                      'Mon Coloc',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Connectez-vous pour continuer',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _decorationChamp(
                      label: 'Adresse email',
                      icone: Icons.email_outlined,
                      theme: theme,
                    ),
                    validator: (val) {
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
                  const SizedBox(height: 18),

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
                        return 'Veuillez entrer votre mot de passe';
                      }
                      if (val.length < 6) {
                        return 'Le mot de passe doit contenir au moins 6 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Bouton Se connecter
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _enChargement ? null : _connecter,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _enChargement
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Se connecter',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Lien vers inscription
                  Center(
                    child: TextButton(
                      onPressed: _allerInscription,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Pas encore de compte ? ',
                            ),
                            TextSpan(
                              text: 'Créez-en un',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decorationChamp({
    required String label,
    required IconData icone,
    required ThemeData theme,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant,
        fontSize: 14,
      ),
      prefixIcon: Icon(icone, color: theme.colorScheme.outline, size: 20),
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