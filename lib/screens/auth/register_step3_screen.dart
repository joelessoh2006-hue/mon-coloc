// Étape 3 : Habitudes de vie pour la compatibilité
// Collecte : Propreté, Rythme de vie (lève-tôt/couche-tard), Fumeur (oui/non)

import 'package:flutter/material.dart';
import 'package:mon_coloc/models/user_model.dart';

class RegisterStep3Screen extends StatefulWidget {
  final void Function({
    required Proprete proprete,
    required RythmeDeVie rythmeDeVie,
    required bool fumeur,
  }) onTerminer;

  final VoidCallback onRetour;

  const RegisterStep3Screen({
    super.key,
    required this.onTerminer,
    required this.onRetour,
  });

  @override
  State<RegisterStep3Screen> createState() => _RegisterStep3ScreenState();
}

class _RegisterStep3ScreenState extends State<RegisterStep3Screen> {
  Proprete? _propreteChoisie;
  RythmeDeVie? _rythmeChoisi;
  bool? _fumeurChoisi;

  void _soumettre() {
    if (_propreteChoisie == null) {
      _afficherErreur('Veuillez indiquer votre niveau de propreté.');
      return;
    }
    if (_rythmeChoisi == null) {
      _afficherErreur('Veuillez indiquer votre rythme de vie.');
      return;
    }
    if (_fumeurChoisi == null) {
      _afficherErreur('Veuillez indiquer si vous fumez.');
      return;
    }

    widget.onTerminer(
      proprete: _propreteChoisie!,
      rythmeDeVie: _rythmeChoisi!,
      fumeur: _fumeurChoisi!,
    );
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _construireEnTete(theme),
                    const SizedBox(height: 32),

                    // Propreté
                    Text(
                      'Niveau de propreté',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Comment décririez-vous votre rapport à la propreté ?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _carteProprete(
                      valeur: Proprete.tresPropre,
                      icone: Icons.auto_fix_high_rounded,
                      titre: 'Très propre',
                      description: 'Tout doit être impeccable en permanence',
                      couleur: const Color(0xFF0891B2),
                    ),
                    const SizedBox(height: 10),
                    _carteProprete(
                      valeur: Proprete.propre,
                      icone: Icons.cleaning_services_rounded,
                      titre: 'Propre',
                      description: 'Je nettoie régulièrement sans être maniaque',
                      couleur: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(height: 10),
                    _carteProprete(
                      valeur: Proprete.moyen,
                      icone: Icons.blur_on_rounded,
                      titre: 'Moyen',
                      description:
                          'Un peu de désordre ne me dérange pas',
                      couleur: const Color(0xFFD97706),
                    ),
                    const SizedBox(height: 28),

                    // Rythme de vie
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Rythme de vie',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quel est votre rythme de vie quotidien ?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _carteRythme(
                      valeur: RythmeDeVie.leveTot,
                      icone: Icons.wb_sunny_rounded,
                      titre: 'Lève-tôt',
                      description: 'Je me couche tôt et me lève tôt',
                      couleur: const Color(0xFFD97706),
                    ),
                    const SizedBox(height: 10),
                    _carteRythme(
                      valeur: RythmeDeVie.coucheTard,
                      icone: Icons.nightlight_round,
                      titre: 'Couche-tard',
                      description: 'Je suis plus actif(ve) en soirée / nuit',
                      couleur: const Color(0xFF1E40AF),
                    ),
                    const SizedBox(height: 28),

                    // Fumeur
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Tabac',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Êtes-vous fumeur / fumeuse ?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _carteFumeur(
                            valeur: false,
                            icone: Icons.smoke_free_rounded,
                            titre: 'Non-fumeur',
                            couleur: const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _carteFumeur(
                            valeur: true,
                            icone: Icons.smoking_rooms_rounded,
                            titre: 'Fumeur',
                            couleur: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Navigation
            _construireNavigation(theme),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Étape 3 sur 3',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Vos habitudes de vie',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ces informations nous aident à trouver des colocataires compatibles avec vous.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _carteProprete({
    required Proprete valeur,
    required IconData icone,
    required String titre,
    required String description,
    required Color couleur,
  }) {
    final bool estSelectionne = _propreteChoisie == valeur;

    return GestureDetector(
      onTap: () => setState(() => _propreteChoisie = valeur),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: estSelectionne ? couleur.withOpacity(0.07) : Colors.white,
          border: Border.all(
            color: estSelectionne ? couleur : const Color(0xFFE5E7EB),
            width: estSelectionne ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: estSelectionne
                    ? couleur
                    : couleur.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icone,
                size: 22,
                color: estSelectionne ? Colors.white : couleur,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: estSelectionne
                          ? couleur
                          : const Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (estSelectionne)
              Icon(Icons.check_circle_rounded, color: couleur, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _carteRythme({
    required RythmeDeVie valeur,
    required IconData icone,
    required String titre,
    required String description,
    required Color couleur,
  }) {
    final bool estSelectionne = _rythmeChoisi == valeur;

    return GestureDetector(
      onTap: () => setState(() => _rythmeChoisi = valeur),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: estSelectionne ? couleur.withOpacity(0.07) : Colors.white,
          border: Border.all(
            color: estSelectionne ? couleur : const Color(0xFFE5E7EB),
            width: estSelectionne ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: estSelectionne
                    ? couleur
                    : couleur.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icone,
                size: 22,
                color: estSelectionne ? Colors.white : couleur,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: estSelectionne
                          ? couleur
                          : const Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (estSelectionne)
              Icon(Icons.check_circle_rounded, color: couleur, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _carteFumeur({
    required bool valeur,
    required IconData icone,
    required String titre,
    required Color couleur,
  }) {
    final bool estSelectionne = _fumeurChoisi == valeur;

    return GestureDetector(
      onTap: () => setState(() => _fumeurChoisi = valeur),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: estSelectionne ? couleur.withOpacity(0.07) : Colors.white,
          border: Border.all(
            color: estSelectionne ? couleur : const Color(0xFFE5E7EB),
            width: estSelectionne ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icone,
              size: 36,
              color: estSelectionne ? couleur : couleur.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              titre,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: estSelectionne
                    ? couleur
                    : const Color(0xFF1E3A5F),
              ),
            ),
            if (estSelectionne) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle_rounded,
                  color: couleur, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _construireNavigation(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: widget.onRetour,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Retour'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              side: BorderSide(color: theme.colorScheme.outline),
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
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
                    Icon(Icons.check_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Terminer l'inscription",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}