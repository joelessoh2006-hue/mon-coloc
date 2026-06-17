// Étape 2 : Critères de logement
// Collecte : Budget max en F CFA, Quartier(s) ciblé(s) à Abidjan, Statut logement,
//            Sexe, Accepte mixité

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mon_coloc/models/user_model.dart';

class RegisterStep2Screen extends StatefulWidget {
  final void Function({
    required double budgetMaxFCFA,
    required List<String> quartierCible,
    required StatutLogement statutLogement,
    required Sexe sexe,
    required bool accepteMixite,
  }) onSuivant;

  final VoidCallback onRetour;
  final String ecoleUniversite;

  const RegisterStep2Screen({
    super.key,
    required this.onSuivant,
    required this.onRetour,
    required this.ecoleUniversite,
  });

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  final _cleForm = GlobalKey<FormState>();
  final _budgetCtrl = TextEditingController();
  double _budgetSliderValue = 100000;

  StatutLogement? _statutChoisi;
  Sexe? _sexeChoisi;
  bool _accepteMixite = false;

  // Multi-sélection des quartiers
  final Set<String> _quartiersSelectionnes = {};
  bool _indifferent = false;

  // Quartiers prioritaires (proches universités) en premier
  static const List<String> _quartiersPrioritaires = [
    'Cocody',
    'Angré',
    'Riviera',
  ];

  // Le reste des quartiers (ordre alphabétique)
  static const List<String> _autresQuartiers = [
    'Abobo',
    'Adjamé',
    'Bingerville',
    'Koumassi',
    'Marcory',
    'Plateau',
    'Port-Bouët',
    'Treichville',
    'Yopougon',
  ];

  /// Tous les quartiers : prioritaires d'abord, puis les autres
  List<String> get _tousLesQuartiers =>
      [..._quartiersPrioritaires, ..._autresQuartiers];

  /// Mapping école → quartier principal pour pré-sélection intelligente
  static const Map<String, String> _ecoleToQuartier = {
    'Université Félix Houphouët-Boigny (UFHB)': 'Cocody',
    'HEC Abidjan': 'Cocody',
    'INP-HB Yamoussoukro': 'Cocody',
    'ISTC': 'Cocody',
    'UCAO-UUA (Université Catholique de l\'Afrique de l\'Ouest)': 'Cocody',
    'CERAP/UJ (Centre de Recherche et d\'Action pour la Paix)': 'Cocody',
    'ESATIC': 'Riviera',
    'PIGIER Abidjan': 'Angré',
    'INPHB': 'Angré',
  };

  @override
  void initState() {
    super.initState();
    // Pré-sélection intelligente : on coche le quartier correspondant à l'école
    final quartierAuto = _ecoleToQuartier[widget.ecoleUniversite];
    if (quartierAuto != null) {
      _quartiersSelectionnes.add(quartierAuto);
    }
  }

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
    if (_sexeChoisi == null) {
      _afficherErreur('Veuillez sélectionner votre sexe.');
      return;
    }

    if (_statutChoisi == StatutLogement.chercheUnLogement) {
      if (_quartiersSelectionnes.isEmpty && !_indifferent) {
        _afficherErreur(
          'Veuillez sélectionner au moins un quartier/commune, '
          'ou choisir "Indifférent / Toute la ville".',
        );
        return;
      }
    }

    final quartiers =
        _indifferent ? <String>[] : _quartiersSelectionnes.toList();

    widget.onSuivant(
      budgetMaxFCFA: double.parse(_budgetCtrl.text.trim()),
      quartierCible: quartiers,
      statutLogement: _statutChoisi!,
      sexe: _sexeChoisi!,
      accepteMixite: _accepteMixite,
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
                      if (estChercheLogement)
                        ..._construireSectionChercheLogement(theme),
                      if (estDejaLogement)
                        ..._construireSectionDejaLogement(theme),
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

      // ---- Commune / Quartier ciblée ----
      Row(
        children: [
          Icon(Icons.location_on_outlined,
              size: 20, color: theme.colorScheme.onSurface),
          const SizedBox(width: 8),
          Text(
            'Commune / Quartier ciblée',
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

      // Chips des quartiers (prioritaires en premier)
      if (!_indifferent)
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _tousLesQuartiers.map((quartier) {
            final estSelectionne = _quartiersSelectionnes.contains(quartier);
            final estPrioritaire =
                _quartiersPrioritaires.contains(quartier);

            return FilterChip(
              label: Text(
                quartier,
                style: TextStyle(
                  fontWeight:
                      estPrioritaire ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              selected: estSelectionne,
              selectedColor: theme.colorScheme.primary,
              checkmarkColor: Colors.white,
              backgroundColor: estPrioritaire && !estSelectionne
                  ? const Color(0xFFF0FDF4)
                  : theme.colorScheme.surfaceContainerLow,
              avatar: estPrioritaire && !estSelectionne
                  ? const Icon(Icons.star_rounded,
                      size: 16, color: Color(0xFF16A34A))
                  : null,
              side: BorderSide(
                color: estSelectionne
                    ? theme.colorScheme.primary
                    : estPrioritaire
                        ? const Color(0xFFBBF7D0)
                        : theme.colorScheme.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              onSelected: (_) => _basculerQuartier(quartier),
            );
          }).toList(),
        ),
      const SizedBox(height: 8),

      // Compteur de sélection
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

      // ---- Sexe ----
      Text(
        'Sexe',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _carteSexe(
              sexe: Sexe.homme,
              icone: Icons.male_rounded,
              label: 'Homme',
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _carteSexe(
              sexe: Sexe.femme,
              icone: Icons.female_rounded,
              label: 'Femme',
              theme: theme,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),

      // ---- Accepte la mixité ----
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _accepteMixite
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: SwitchListTile(
          title: Text(
            'Acceptes-tu des colocataires du sexe opposé ?',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            _accepteMixite
                ? 'Oui, je suis ouvert(e) à la mixité'
                : 'Non, je préfère un colocataire du même sexe',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          secondary: Icon(
            _accepteMixite
                ? Icons.group_rounded
                : Icons.person_pin_rounded,
            color: _accepteMixite
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          value: _accepteMixite,
          activeColor: theme.colorScheme.primary,
          onChanged: (val) => setState(() => _accepteMixite = val),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
  // Carte de sélection du sexe
  // ---------------------------------------------------------------------------
  Widget _carteSexe({
    required Sexe sexe,
    required IconData icone,
    required String label,
    required ThemeData theme,
  }) {
    final estSelectionne = _sexeChoisi == sexe;

    return GestureDetector(
      onTap: () => setState(() => _sexeChoisi = sexe),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: estSelectionne
              ? theme.colorScheme.primary.withOpacity(0.06)
              : Colors.white,
          border: Border.all(
            color: estSelectionne
                ? theme.colorScheme.primary
                : const Color(0xFFE5E7EB),
            width: estSelectionne ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: estSelectionne
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : Colors.black.withOpacity(0.04),
              blurRadius: estSelectionne ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icone,
              size: 32,
              color: estSelectionne
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: estSelectionne
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
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