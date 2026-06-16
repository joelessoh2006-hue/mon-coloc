// Étape 2 : Critères de logement
// Collecte : Budget max en F CFA, Quartier(s) ciblé(s) à Abidjan, Statut logement

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mon_coloc/models/user_model.dart';

class RegisterStep2Screen extends StatefulWidget {
  final void Function({
    required double budgetMaxFCFA,
    required List<String> quartierCible,
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
  double _budgetSliderValue = 100000; // valeur par défaut

  StatutLogement? _statutChoisi;

  // Multi-sélection des quartiers
  final Set<String> _quartiersSelectionnes = {};
  bool _indifferent = false;

  // Liste complète des quartiers
  static const List<String> _tousLesQuartiers = [
    'Cocody',
    'Angré',
    'Riviera',
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

  // Quartiers proches des universités (mis en avant)
  static const Set<String> _quartiersUniversite = {
    'Cocody',
    'Angré',
    'Riviera',
  };

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _soumettre() {
    if (!_cleForm.currentState!.validate()) return;
    if (_statutChoisi == null) {
      _afficherErreur('Veuillez indiquer votre statut.');
      return;
    }

    if (_statutChoisi == StatutLogement.chercheUnLogement) {
      // Validation pour le mode "Je cherche un logement"
      if (_quartiersSelectionnes.isEmpty && !_indifferent) {
        _afficherErreur(
          'Veuillez sélectionner au moins un quartier/commune, '
          'ou choisir "Indifférent / Toute la ville".',
        );
        return;
      }
    }

    // Si "Indifférent" est coché, on envoie une liste vide
    final quartiers = _indifferent ? <String>[] : _quartiersSelectionnes.toList();

    widget.onSuivant(
      budgetMaxFCFA: double.parse(_budgetCtrl.text.trim()),
      quartierCible: quartiers,
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

  void _basculerQuartier(String quartier) {
    setState(() {
      if (_quartiersSelectionnes.contains(quartier)) {
        _quartiersSelectionnes.remove(quartier);
      } else {
        _quartiersSelectionnes.add(quartier);
      }
    });
  }

  void _basculerIndifferent(bool? value) {
    setState(() {
      _indifferent = value ?? false;
      if (_indifferent) {
        _quartiersSelectionnes.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estChercheLogement =
        _statutChoisi == StatutLogement.chercheUnLogement;
    final estDejaLogement =
        _statutChoisi == StatutLogement.aDejaUnLogement;

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

                      // ---- Votre situation (TOUT EN HAUT) ----
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

                      // ---- Contenu conditionnel selon le statut ----
                      if (estChercheLogement) ..._construireSectionChercheLogement(theme),
                      if (estDejaLogement) ..._construireSectionDejaLogement(theme),
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
  // Section "Je cherche un logement"
  // ---------------------------------------------------------------------------
  List<Widget> _construireSectionChercheLogement(ThemeData theme) {
    return [
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
      const SizedBox(height: 12),

      // Slider du budget
      Row(
        children: [
          const Icon(Icons.attach_money, size: 18, color: Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(
            'Ajustez avec le curseur',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: theme.colorScheme.primary,
          inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
          thumbColor: theme.colorScheme.primary,
          overlayColor: theme.colorScheme.primary.withOpacity(0.12),
          valueIndicatorColor: theme.colorScheme.primary,
          valueIndicatorTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Slider(
          min: 50000,
          max: 1000000,
          divisions: 19,
          value: _budgetSliderValue,
          label: '${_budgetSliderValue.toInt().toString()} F CFA',
          onChanged: (val) {
            setState(() {
              _budgetSliderValue = val;
              _budgetCtrl.text = val.toInt().toString();
            });
          },
        ),
      ),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_budgetSliderValue.toInt().toString()} F CFA / mois',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      const SizedBox(height: 28),

      // Quartier/Commune ciblée - Multi-sélection
      Row(
        children: [
          Icon(Icons.location_on_outlined,
              size: 20, color: theme.colorScheme.onSurface),
          const SizedBox(width: 8),
          Text(
            'Quartier/Commune ciblée',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Sélectionnez un ou plusieurs quartiers',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 4),

      // Option "Indifférent / Toute la ville"
      Card(
        color: _indifferent
            ? theme.colorScheme.primaryContainer.withOpacity(0.4)
            : null,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _indifferent
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: _indifferent ? 1.5 : 1,
          ),
        ),
        child: CheckboxListTile(
          title: Text(
            'Indifférent / Toute la ville',
            style: TextStyle(
              fontWeight: _indifferent ? FontWeight.w700 : FontWeight.w500,
              color: _indifferent
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            'Aucune préférence de quartier',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          secondary: Icon(
            Icons.explore_outlined,
            color: _indifferent
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          value: _indifferent,
          activeColor: theme.colorScheme.primary,
          onChanged: _basculerIndifferent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          controlAffinity: ListTileControlAffinity.trailing,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
      ),
      const SizedBox(height: 12),

      // Chips des quartiers
      if (!_indifferent)
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _tousLesQuartiers.map((quartier) {
            final estSelectionne = _quartiersSelectionnes.contains(quartier);
            final estUniversitaire = _quartiersUniversite.contains(quartier);

            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (estUniversitaire) ...[
                    Icon(
                      Icons.school,
                      size: 16,
                      color: estSelectionne ? Colors.white : const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(quartier),
                  if (estUniversitaire) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: estSelectionne
                            ? Colors.white.withOpacity(0.25)
                            : const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Université',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: estSelectionne
                              ? Colors.white
                              : const Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: estSelectionne,
              selectedColor: theme.colorScheme.primary,
              checkmarkColor: Colors.white,
              backgroundColor: estUniversitaire && !estSelectionne
                  ? const Color(0xFFF5F3FF)
                  : theme.colorScheme.surfaceContainerLow,
              side: BorderSide(
                color: estSelectionne
                    ? theme.colorScheme.primary
                    : estUniversitaire
                        ? const Color(0xFFDDD6FE)
                        : theme.colorScheme.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: estSelectionne
                      ? theme.colorScheme.primary
                      : estUniversitaire
                          ? const Color(0xFFDDD6FE)
                          : theme.colorScheme.outlineVariant,
                ),
              ),
              onSelected: (_) => _basculerQuartier(quartier),
            );
          }).toList(),
        ),
      const SizedBox(height: 8),

      // Affichage du nombre de quartiers sélectionnés
      if (!_indifferent && _quartiersSelectionnes.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '${_quartiersSelectionnes.length} quartier${_quartiersSelectionnes.length > 1 ? 's' : ''} sélectionné${_quartiersSelectionnes.length > 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 32),
    ];
  }

  // ---------------------------------------------------------------------------
  // Section "J'ai déjà un logement" (Bientôt disponible)
  // ---------------------------------------------------------------------------
  List<Widget> _construireSectionDejaLogement(ThemeData theme) {
    return [
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7).withOpacity(0.5),
          border: Border.all(
            color: const Color(0xFFFDE68A),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.construction_rounded,
              size: 48,
              color: const Color(0xFFD97706),
            ),
            const SizedBox(height: 16),
            Text(
              'Formulaire de dépôt de logement',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bientôt disponible avec le module Bailleur',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFA16207),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Icon(
              Icons.hourglass_bottom,
              size: 28,
              color: const Color(0xFFD97706).withOpacity(0.6),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
    ];
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
          color: estSelectionne ? couleur.withOpacity(0.06) : Colors.white,
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
                color: estSelectionne ? couleur : couleur.withOpacity(0.10),
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
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}