// Étape 2 : Critères de logement
// Collecte : Budget max en F CFA, Quartier ciblé à Abidjan, Statut logement

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mon_coloc/models/user_model.dart';

class RegisterStep2Screen extends StatefulWidget {
  final void Function({
    required double budgetMaxFCFA,
    required String quartierCible,
    required StatutLogement statutLogement,
  }) onSuivant;

  final VoidCallback onRetour;

  const RegisterStep2Screen({
    super.key,
    required this.onSuivant,
    required this.onRetour,
  });

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  final _cleForm = GlobalKey<FormState>();
  final _budgetCtrl = TextEditingController();

  String? _quartierChoisi;
  StatutLogement? _statutChoisi;

  static const List<String> _listeQuartiers = [
    'Angré',
    'Riviera',
    'Cocody',
    'Yopougon',
    'Marcory',
    'Koumassi',
    'Adjamé',
    'Plateau',
    'Treichville',
    'Abobo',
    'Bingerville',
    'Port-Bouët',
  ];

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _soumettre() {
    if (!_cleForm.currentState!.validate()) return;
    if (_quartierChoisi == null) {
      _afficherErreur('Veuillez sélectionner un quartier ciblé.');
      return;
    }
    if (_statutChoisi == null) {
      _afficherErreur('Veuillez indiquer votre statut.');
      return;
    }

    widget.onSuivant(
      budgetMaxFCFA: double.parse(_budgetCtrl.text.trim()),
      quartierCible: _quartierChoisi!,
      statutLogement: _statutChoisi!,
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
                child: Form(
                  key: _cleForm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _construireEnTete(theme),
                      const SizedBox(height: 32),

                      // Budget maximum
                      Text(
                        'Budget mensuel maximum',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _budgetCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _decorationChamp(
                          label: 'Montant en F CFA',
                          icone: Icons.payments_outlined,
                          theme: theme,
                          suffixText: 'F CFA',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Veuillez entrer votre budget mensuel';
                          }
                          final montant = double.tryParse(val.trim());
                          if (montant == null || montant <= 0) {
                            return 'Montant invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Quartier ciblé
                      Text(
                        'Quartier ciblé à Abidjan',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _quartierChoisi,
                        isExpanded: true,
                        decoration: _decorationChamp(
                          label: 'Sélectionnez un quartier',
                          icone: Icons.location_on_outlined,
                          theme: theme,
                        ),
                        items: _listeQuartiers
                            .map(
                              (q) =>
                                  DropdownMenuItem(value: q, child: Text(q)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _quartierChoisi = val),
                        validator: (val) =>
                            val == null ? 'Veuillez choisir un quartier' : null,
                      ),
                      const SizedBox(height: 24),

                      // Statut
                      Text(
                        'Votre situation',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _carteStatut(
                        statut: StatutLogement.chercheUnLogement,
                        icone: Icons.search_rounded,
                        titre: 'Je cherche un logement',
                        description:
                            'Je recherche une chambre ou un colocataire',
                        couleur: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      _carteStatut(
                        statut: StatutLogement.aDejaUnLogement,
                        icone: Icons.home_rounded,
                        titre: "J'ai déjà un logement",
                        description:
                            'Je cherche un colocataire pour partager le loyer',
                        couleur: const Color(0xFF059669),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
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
            'Étape 2 sur 3',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Vos critères de logement',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Aidez-nous à trouver le logement idéal pour vous.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _carteStatut({
    required StatutLogement statut,
    required IconData icone,
    required String titre,
    required String description,
    required Color couleur,
  }) {
    final bool estSelectionne = _statutChoisi == statut;

    return GestureDetector(
      onTap: () => setState(() => _statutChoisi = statut),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              estSelectionne ? couleur.withOpacity(0.06) : Colors.white,
          border: Border.all(
            color: estSelectionne ? couleur : const Color(0xFFE5E7EB),
            width: estSelectionne ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: estSelectionne
                  ? couleur.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: estSelectionne ? 14 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: estSelectionne
                    ? couleur
                    : couleur.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icone,
                size: 28,
                color: estSelectionne ? Colors.white : couleur,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: estSelectionne
                          ? couleur
                          : const Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: estSelectionne ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.check_circle_rounded,
                color: couleur,
                size: 24,
              ),
            ),
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
                    Text(
                      'Suivant',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decorationChamp({
    required String label,
    required IconData icone,
    required ThemeData theme,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant,
        fontSize: 14,
      ),
      prefixIcon: Icon(icone, color: theme.colorScheme.outline, size: 20),
      suffixText: suffixText,
      suffixStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
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