// Étape 3 : Habitudes de vie pour la compatibilité + Sexe & Préférence de mixité
// Collecte : Propreté, Rythme de vie, Fumeur, Animaux, Bruit, Études, Sexe, Accepte mixité

import 'package:flutter/material.dart';
import 'package:mon_coloc/models/user_model.dart';

class RegisterStep3Screen extends StatefulWidget {
  final void Function({
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
  // Sexe & Préférence de mixité
  Sexe? _sexeChoisi;
  bool _accepteMixite = false;

  // Sections existantes
  Proprete? _propreteChoisie;
  RythmeDeVie? _rythmeChoisi;
  bool? _fumeurChoisi;

  // Animaux
  StatutAnimaux? _statutAnimaux;
  final _animauxCtrl = TextEditingController();

  // Bruit & Ambiance
  bool _bruitsForts = false;
  bool _appelsFrequents = false;
  bool _soireesAmis = false;

  // Études — initialisée avec une valeur par défaut pour éviter le bug SegmentedButton
  bool _besoinSilence = false;
  HoraireRevision _horaireRevision = HoraireRevision.jour;

  @override
  void dispose() {
    _animauxCtrl.dispose();
    super.dispose();
  }

  void _soumettre() {
    if (_sexeChoisi == null) {
      _afficherErreur('Veuillez sélectionner votre sexe.');
      return;
    }
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
    if (_statutAnimaux == null) {
      _afficherErreur('Veuillez indiquer votre statut concernant les animaux.');
      return;
    }

    widget.onTerminer(
      sexe: _sexeChoisi!,
      accepteMixite: _accepteMixite,
      proprete: _propreteChoisie!,
      rythmeDeVie: _rythmeChoisi!,
      fumeur: _fumeurChoisi!,
      statutAnimaux: _statutAnimaux!,
      typeAnimaux: _statutAnimaux == StatutAnimaux.enAPossession
          ? _animauxCtrl.text.trim()
          : null,
      bruitsFortsVolume: _bruitsForts,
      appelsFrequents: _appelsFrequents,
      soireesAmis: _soireesAmis,
      besoinSilence: _besoinSilence,
      horaireRevision: _horaireRevision,
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

                    // ---- Message d'avertissement ----
                    _construireMessageAvertissement(theme),
                    const SizedBox(height: 28),

                    // ---- Sexe de l'utilisateur ----
                    Text(
                      'Sexe de l\'utilisateur',
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

                    // ---- Préférence de colocation mixte ----
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
                          'Acceptez-vous les colocataires du sexe opposé ?',
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

                    // ---- Propreté ----
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
                      description:
                          'Je nettoie régulièrement sans être maniaque',
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

                    // ---- Rythme de vie ----
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

                    // ---- Tabac ----
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
                    const SizedBox(height: 28),

                    // ---- Animaux de compagnie ----
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Animaux de compagnie',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'As-tu ou acceptes-tu les animaux ?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _carteAnimaux(
                      valeur: StatutAnimaux.non,
                      icone: Icons.block_rounded,
                      titre: 'Non',
                      description: 'Je ne souhaite pas d\'animaux',
                      couleur: const Color(0xFF6B7280),
                    ),
                    const SizedBox(height: 10),
                    _carteAnimaux(
                      valeur: StatutAnimaux.enAPossession,
                      icone: Icons.pets_rounded,
                      titre: 'J\'en ai',
                      description: 'Je possède déjà un ou plusieurs animaux',
                      couleur: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(height: 10),
                    _carteAnimaux(
                      valeur: StatutAnimaux.tolere,
                      icone: Icons.emoji_nature_rounded,
                      titre: 'Je n\'en ai pas mais je les tolère',
                      description:
                          'Je n\'en ai pas mais je les accepte',
                      couleur: const Color(0xFF0891B2),
                    ),

                    // Champ texte si "J'en ai"
                    if (_statutAnimaux == StatutAnimaux.enAPossession) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _animauxCtrl,
                        decoration: InputDecoration(
                          labelText: 'Quel(s) animal/animaux possèdes-tu ?',
                          hintText: 'Ex: Chat, Chien...',
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.edit_outlined,
                              color: theme.colorScheme.outline, size: 20),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: theme.colorScheme.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: theme.colorScheme.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: theme.colorScheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // ---- Bruit et Ambiance sonore ----
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Bruit et Ambiance sonore',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Comment vis-tu l\'ambiance sonore au quotidien ?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _interrupteurBruit(
                      titre: 'Musique forte',
                      icone: Icons.volume_up_rounded,
                      valeur: _bruitsForts,
                      onChanged: (val) =>
                          setState(() => _bruitsForts = val),
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _interrupteurBruit(
                      titre: 'Appels longs',
                      icone: Icons.phone_in_talk_rounded,
                      valeur: _appelsFrequents,
                      onChanged: (val) =>
                          setState(() => _appelsFrequents = val),
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _interrupteurBruit(
                      titre: 'Organise des soirées',
                      icone: Icons.celebration_rounded,
                      valeur: _soireesAmis,
                      onChanged: (val) =>
                          setState(() => _soireesAmis = val),
                      theme: theme,
                    ),
                    const SizedBox(height: 28),

                    // ---- Habitudes d'étude ----
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Habitudes d\'étude',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Spécial étudiant — adaptons la colocation à ton rythme',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _besoinSilence
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          'Besoin de silence absolu pour réviser',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          _besoinSilence
                              ? 'Oui, j\'ai besoin de calme'
                              : 'Non, le bruit ne me dérange pas',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        secondary: Icon(
                          _besoinSilence
                              ? Icons.volume_mute_rounded
                              : Icons.hearing_rounded,
                          color: _besoinSilence
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        value: _besoinSilence,
                        activeColor: theme.colorScheme.primary,
                        onChanged: (val) =>
                            setState(() => _besoinSilence = val),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rythme de travail / révision
                    Text(
                      'Rythme de travail',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quand préfères-tu réviser ou travailler ?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<HoraireRevision>(
                      segments: const [
                        ButtonSegment(
                          value: HoraireRevision.jour,
                          icon: Icon(Icons.light_mode_rounded),
                          label: Text('Plutôt de jour'),
                        ),
                        ButtonSegment(
                          value: HoraireRevision.nuit,
                          icon: Icon(Icons.nightlight_round),
                          label: Text('Plutôt de nuit'),
                        ),
                        ButtonSegment(
                          value: HoraireRevision.flexible,
                          icon: Icon(Icons.schedule_rounded),
                          label: Text('Flexible'),
                        ),
                      ],
                      selected: {_horaireRevision},
                      onSelectionChanged: (Set<HoraireRevision> selected) {
                        setState(() => _horaireRevision = selected.first);
                      },
                      style: ButtonStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
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
  // Message d'avertissement
  // ---------------------------------------------------------------------------
  Widget _construireMessageAvertissement(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(
          color: const Color(0xFFFFEDD5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              size: 24,
              color: Color(0xFFEA580C),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Information importante',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9A3412),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'S\'il vous plaît, remplissez ces informations de la manière la plus honnête possible. '
                  'Soyez véridiques dans vos réponses, car il y va de la qualité et du confort '
                  'de votre future colocation !',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFC2410C),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Interrupteur pour le bruit
  // ---------------------------------------------------------------------------
  Widget _interrupteurBruit({
    required String titre,
    required IconData icone,
    required bool valeur,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: valeur
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: SwitchListTile(
        secondary: Icon(
          icone,
          color: valeur ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        title: Text(
          titre,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        value: valeur,
        activeColor: theme.colorScheme.primary,
        onChanged: onChanged,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Carte Animaux
  // ---------------------------------------------------------------------------
  Widget _carteAnimaux({
    required StatutAnimaux valeur,
    required IconData icone,
    required String titre,
    required String description,
    required Color couleur,
  }) {
    final bool estSelectionne = _statutAnimaux == valeur;

    return GestureDetector(
      onTap: () => setState(() => _statutAnimaux = valeur),
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
                color: estSelectionne ? couleur : couleur.withOpacity(0.10),
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

  // ---------------------------------------------------------------------------
  // Widgets existants (conservés)
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
          'Vos habitudes de vie & Profil',
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
                color: estSelectionne ? couleur : couleur.withOpacity(0.10),
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
                color: estSelectionne ? couleur : couleur.withOpacity(0.10),
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
                color: estSelectionne ? couleur : const Color(0xFF1E3A5F),
              ),
            ),
            if (estSelectionne) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle_rounded, color: couleur, size: 18),
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