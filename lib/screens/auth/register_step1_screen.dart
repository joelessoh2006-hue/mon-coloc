// Étape 1 : Authentification Firebase (Email, MDP) + Infos perso
// Collecte : Nom, Prénom, Email, Mot de passe, Téléphone (+225), École/Université, Date de naissance
// Le rôle est déjà sélectionné dans RoleSelectionScreen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mon_coloc/screens/home_screen.dart';
import 'package:intl/intl.dart';

class RegisterStep1Screen extends StatefulWidget {
  final Future<void> Function({
    required String nom,
    required String prenom,
    required String email,
    required String motDePasse,
    required String telephone,
    required String ecoleUniversite,
    required DateTime? dateNaissance,
    required int? age,
  })
  onSuivant;

  const RegisterStep1Screen({super.key, required this.onSuivant});

  @override
  State<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends State<RegisterStep1Screen> {
  final _cleForm = GlobalKey<FormState>();

  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mdpCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _autreEcoleCtrl = TextEditingController();

  String? _ecoleChoisie;
  bool _mdpVisible = false;

  // Date de naissance
  DateTime? _dateNaissance;
  int? _ageCalcule;

  static const List<String> _listeEcoles = [
    'HEC Abidjan',
    'Université Félix Houphouët-Boigny (UFHB)',
    'INP-HB Yamoussoukro',
    'ESATIC',
    'PIGIER Abidjan',
    'ISTC',
    'INPHB',
    'UCAO-UUA (Université Catholique de l\'Afrique de l\'Ouest)',
    'CERAP/UJ (Centre de Recherche et d\'Action pour la Paix)',
    'Autre',
  ];

  bool get _estAutre => _ecoleChoisie == 'Autre';

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    _telCtrl.dispose();
    _autreEcoleCtrl.dispose();
    super.dispose();
  }

  /// Ouvre le sélecteur de date natif Flutter
  Future<void> _ouvrirDatePicker() async {
    final now = DateTime.now();
    final ageMin = now.year - 15; // Âge minimum : 15 ans
    final dateMax = DateTime(ageMin, now.month, now.day);
    final dateMin = DateTime(now.year - 100); // Max 100 ans en arrière

    final picked = await showDatePicker(
      context: context,
      initialDate:
          _dateNaissance ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: dateMin,
      lastDate: dateMax,
      helpText: 'Sélectionnez votre date de naissance',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
      locale: const Locale('fr', 'FR'),
    );

    if (picked != null) {
      setState(() {
        _dateNaissance = picked;
        _ageCalcule = _calculerAge(picked);
      });
    }
  }

  /// Calcule l'âge exact à partir d'une date de naissance
  int _calculerAge(DateTime dateNaissance) {
    final now = DateTime.now();
    int age = now.year - dateNaissance.year;
    if (now.month < dateNaissance.month ||
        (now.month == dateNaissance.month && now.day < dateNaissance.day)) {
      age--;
    }
    return age;
  }

  /// Formate la date au format JJ/MM/AAAA
  String _formaterDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _soumettre() async {
    if (!_cleForm.currentState!.validate()) return;
    if (_ecoleChoisie == null) {
      _afficherErreur('Veuillez sélectionner votre école ou université.');
      return;
    }
    if (_dateNaissance == null) {
      _afficherErreur('Veuillez sélectionner votre date de naissance.');
      return;
    }

    // Si "Autre" est sélectionné, utiliser la valeur saisie dans le champ texte
    final ecoleFinale = _estAutre
        ? _autreEcoleCtrl.text.trim()
        : _ecoleChoisie!;

    if (_estAutre && ecoleFinale.isEmpty) {
      _afficherErreur('Veuillez préciser le nom de votre école ou université.');
      return;
    }

    await widget.onSuivant(
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      motDePasse: _mdpCtrl.text,
      telephone: _telCtrl.text.trim(),
      ecoleUniversite: ecoleFinale,
      dateNaissance: _dateNaissance,
      age: _ageCalcule,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _cleForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    if (!RegExp(
                      r'^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,}$',
                    ).hasMatch(val.trim())) {
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
                const SizedBox(height: 16),

                // Date de naissance (champ cliquable)
                InkWell(
                  onTap: _ouvrirDatePicker,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _decorationChamp(
                      label: 'Date de naissance',
                      icone: Icons.calendar_month_outlined,
                      theme: theme,
                    ),
                    child: Text(
                      _dateNaissance != null
                          ? _formaterDate(_dateNaissance!)
                          : 'Sélectionnez votre date de naissance',
                      style: TextStyle(
                        fontSize: 16,
                        color: _dateNaissance != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Affichage de l'âge calculé si la date est sélectionnée
                if (_ageCalcule != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(
                        0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Vous avez $_ageCalcule ans',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // École / Université
                DropdownButtonFormField<String>(
                  value: _ecoleChoisie,
                  isExpanded: true,
                  decoration: _decorationChamp(
                    label: 'École / Université',
                    icone: Icons.school_outlined,
                    theme: theme,
                  ),
                  items: _listeEcoles
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _ecoleChoisie = val),
                  validator: (val) =>
                      val == null ? 'Veuillez sélectionner votre école' : null,
                ),

                // Champ texte pour "Autre" (visible uniquement si "Autre" est sélectionné)
                if (_estAutre) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _autreEcoleCtrl,
                    decoration: _decorationChamp(
                      label: 'Précisez votre école / université',
                      icone: Icons.edit_outlined,
                      theme: theme,
                    ),
                    validator: (val) {
                      if (_estAutre && (val == null || val.trim().isEmpty)) {
                        return 'Veuillez préciser le nom de votre établissement';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 36),

                _boutonSuivant(theme),
              ],
            ),
          ),
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
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.school_rounded,
            color: theme.colorScheme.onPrimaryContainer,
            size: 26,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Créez votre compte étudiant',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Rejoignez la communauté Mon Coloc à Abidjan',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Étape 1 sur 3',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
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

  Widget _boutonSuivant(ThemeData theme) {
    return SizedBox(
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}
