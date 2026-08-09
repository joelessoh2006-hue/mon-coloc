// Étape 2 : Critères de logement / Informations logement
// Si "Je cherche un logement" : Budget max + Quartiers
// Si "J'ai déjà un logement" : Quartier/Zone, Loyer total, Part loyer, Description
// Le sexe et la mixité ont été déplacés vers l'Étape 3

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class RegisterStep2Screen extends StatefulWidget {
  final void Function({
    required double budgetMaxFCFA,
    required List<String> quartierCible,
    required StatutLogement statutLogement,
    // Champs "J'ai déjà un logement"
    String? logementQuartier,
    double? logementLoyerTotal,
    double? logementPartColoc,
    String? logementDescription,
    List<XFile>? logementPhotos,
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

  // Contrôleurs pour le formulaire "J'ai déjà un logement"
  final _logementQuartierCtrl = TextEditingController();
  final _logementLoyerTotalCtrl = TextEditingController();
  final _logementPartColocCtrl = TextEditingController();
  final _logementDescriptionCtrl = TextEditingController();

  // Ajout pour la sélection de photos
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedPhotos = [];
  static const int _maxPhotos = 5;


  StatutLogement? _statutChoisi;

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
    _logementQuartierCtrl.dispose();
    _logementLoyerTotalCtrl.dispose();
    _logementPartColocCtrl.dispose();
    _logementDescriptionCtrl.dispose();

    super.dispose();
  }

  void _soumettre() {
    if (!_cleForm.currentState!.validate()) return;
    if (_statutChoisi == null) {
      _afficherErreur('Veuillez indiquer votre statut.');
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
    } else if (_statutChoisi == StatutLogement.aDejaUnLogement) {
      if (_selectedPhotos.isEmpty) {
        _afficherErreur(
          'Veuillez ajouter au moins une photo de votre logement.',
        );
        return;
      }
    }

    final quartiers =
        _indifferent ? <String>[] : _quartiersSelectionnes.toList();

    if (_statutChoisi == StatutLogement.aDejaUnLogement) {
      widget.onSuivant(
        budgetMaxFCFA: 0,
        quartierCible: quartiers,
        statutLogement: _statutChoisi!,
        logementQuartier: _logementQuartierCtrl.text.trim(),
        logementLoyerTotal: double.tryParse(_logementLoyerTotalCtrl.text.trim()),
        logementPartColoc: double.tryParse(_logementPartColocCtrl.text.trim()),
        logementDescription: _logementDescriptionCtrl.text.trim(),
        logementPhotos: _selectedPhotos,
      );
    } else {
      widget.onSuivant(
        budgetMaxFCFA: double.parse(_budgetCtrl.text.trim()),
        quartierCible: quartiers,
        statutLogement: _statutChoisi!,
      );
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

  /// Ouvre la galerie pour sélectionner des photos.
  Future<void> _ajouterPhotos() async {
    if (_selectedPhotos.length >= _maxPhotos) {
      _afficherErreur('Vous ne pouvez ajouter que $_maxPhotos photos au maximum.');
      return;
    }

    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (images.isEmpty) return;

      // Limiter le nombre total de photos
      final int remainingSlots = _maxPhotos - _selectedPhotos.length;
      final List<XFile> newImages =
          images.take(remainingSlots).toList();

      setState(() {
        _selectedPhotos.addAll(newImages);
      });

      if (images.length > remainingSlots) {
        _afficherErreur(
          'Limite de $_maxPhotos photos atteinte. Seules les premières ont été ajoutées.',
        );
      }
    } catch (e) {
      _afficherErreur('Erreur lors de la sélection des photos : $e');
    }
  }

  /// Supprime une photo de la liste des photos sélectionnées.
  void _supprimerPhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
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
    ];
  }

  // ---------------------------------------------------------------------------
  // Section "J'ai déjà un logement" — Logement uniquement
  // ---------------------------------------------------------------------------
  List<Widget> _construireSectionDejaLogement(ThemeData theme) {
    return [
      // ---- Section Logement actuel ----
      Text(
        'Votre logement actuel',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Parlez-nous de votre logement pour trouver le bon colocataire',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),

      // Quartier/Zone
      TextFormField(
        controller: _logementQuartierCtrl,
        decoration: _decorationChamp(
          label: 'Quartier / Zone',
          icone: Icons.location_on_outlined,
          theme: theme,
        ),
        validator: (val) {
          if (val == null || val.trim().isEmpty) {
            return 'Veuillez indiquer le quartier ou la zone';
          }
          return null;
        },
      ),
      const SizedBox(height: 14),

      // Loyer mensuel total
      TextFormField(
        controller: _logementLoyerTotalCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: _decorationChamp(
          label: 'Loyer mensuel total',
          icone: Icons.payments_outlined,
          theme: theme,
          suffixText: 'F CFA',
        ),
        validator: (val) {
          if (val == null || val.trim().isEmpty) {
            return 'Veuillez entrer le loyer mensuel total';
          }
          final montant = double.tryParse(val.trim());
          if (montant == null || montant <= 0) {
            return 'Montant invalide';
          }
          return null;
        },
      ),
      const SizedBox(height: 14),

      // Part du loyer demandée au futur colocataire
      TextFormField(
        controller: _logementPartColocCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: _decorationChamp(
          label: 'Part du loyer demandée au futur colocataire',
          icone: Icons.people_outline_rounded,
          theme: theme,
          suffixText: 'F CFA',
        ),
        validator: (val) {
          if (val == null || val.trim().isEmpty) {
            return 'Veuillez entrer la part du loyer pour le colocataire';
          }
          final montant = double.tryParse(val.trim());
          if (montant == null || montant <= 0) {
            return 'Montant invalide';
          }
          return null;
        },
      ),
      const SizedBox(height: 14),

      // Description rapide
      TextFormField(
        controller: _logementDescriptionCtrl,
        maxLines: 3,
        maxLength: 200,
        decoration: _decorationChamp(
          label: 'Description rapide du logement',
          icone: Icons.description_outlined,
          theme: theme,
        ),
        validator: (val) {
          if (val == null || val.trim().isEmpty) {
            return 'Veuillez décrire rapidement votre logement';
          }
          return null;
        },
      ),
      const SizedBox(height: 28),

      // ---- Section Photos du logement ----
      _sectionLabel(
        theme,
        'Photos du logement *',
        'Ajoutez entre 1 et 5 photos de votre logement.',
      ),
      const SizedBox(height: 12),
      _buildPhotoPicker(theme),
      if (_selectedPhotos.isNotEmpty) _buildPhotoPreview(),
      const SizedBox(height: 28),
    ];
  }

  Widget _sectionLabel(ThemeData theme, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
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

  /// Widget pour le sélecteur de photos.
  Widget _buildPhotoPicker(ThemeData theme) {
    final hasPhotos = _selectedPhotos.isNotEmpty;
    final color = hasPhotos ? const Color(0xFF1E6B4E) : Colors.grey;

    return InkWell(
      onTap: _ajouterPhotos,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasPhotos ? Icons.add_photo_alternate_rounded : Icons.add_a_photo_rounded,
              size: 28,
              color: color,
            ),
            const SizedBox(width: 12),
            Text(
              hasPhotos ? 'Ajouter d\'autres photos' : 'Ajouter des photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget pour afficher les miniatures des photos sélectionnées.
  Widget _buildPhotoPreview() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(
          _selectedPhotos.length,
          (index) => _buildPhotoChip(index),
        ),
      ),
    );
  }

  /// Une seule miniature de photo avec un bouton de suppression.
  Widget _buildPhotoChip(int index) {
    final file = _selectedPhotos[index];

    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: kIsWeb
              ? Image.network(
                  file.path,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 80,
                height: 80,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
            },
                )
              : Image.file(
                  File(file.path),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _supprimerPhoto(index),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}