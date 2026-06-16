$content = @'
// Parcours d'inscription progressif pour Mon Coloc
// 3 étapes : Accès Rapide → Le Pivot → Profil de Vie

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../home/accueil_screen.dart';

// ---------------------------------------------------------------------------
// Widget principal : Contrôleur des 3 étapes d'inscription
// ---------------------------------------------------------------------------
class InscriptionScreen extends StatefulWidget {
  const InscriptionScreen({super.key});

  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();
  bool _chargement = false;
  int _etapeCourante = 0;
  String? _uid;

  // Étape 1
  final _cleFormEtape1 = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mdpCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  bool _mdpVisible = false;

  // Étape 2
  String? _situationChoisie;

  // Étape 3
  final _cleFormEtape3 = GlobalKey<FormState>();
  String? _ecoleChoisie;
  final _budgetCtrl = TextEditingController();
  double _niveauProprete = 3;
  double _toleranceBruit = 3;
  final List<String> _habitudesSelectionnees = [];

  static const List<String> _listeEcoles = [
    'HEC', 'UFHB', 'INP-HB', 'INPHB', 'Université FHB',
    'ESATIC', 'PIGIER', 'ISTC', 'Autre',
  ];

  static const List<String> _listeHabitudes = [
    'Non-fumeur', 'Fumeur', 'Couche-tôt', 'Couche-tard',
    'Calme', 'Convivial', 'Sportif', 'Végétarien', 'Religieux', 'Musique',
  ];

  void _allerEtapeSuivante() {
    _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    setState(() => _etapeCourante++);
  }

  void _allerEtapePrecedente() {
    _pageController.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    setState(() => _etapeCourante--);
  }

  Future<void> _validerEtape1() async {
    if (!_cleFormEtape1.currentState!.validate()) return;
    setState(() => _chargement = true);
    try {
      _uid = await _authService.creerCompte(email: _emailCtrl.text, motDePasse: _mdpCtrl.text);
      _allerEtapeSuivante();
    } on Exception catch (e) {
      _afficherErreur(_formaterErreurFirebase(e.toString()));
    } finally {
      setState(() => _chargement = false);
    }
  }

  void _validerEtape2() {
    if (_situationChoisie == null) {
      _afficherErreur('Veuillez choisir votre situation actuelle.');
      return;
    }
    _allerEtapeSuivante();
  }

  Future<void> _validerEtape3EtEnregistrer() async {
    if (!_cleFormEtape3.currentState!.validate()) return;
    if (_ecoleChoisie == null) {
      _afficherErreur('Veuillez sélectionner votre école.');
      return;
    }
    setState(() => _chargement = true);
    try {
      final StudentProfile profilEtudiant = StudentProfile(
        situation: _situationChoisie!,
        school: _ecoleChoisie!,
        maxBudget: double.tryParse(_budgetCtrl.text) ?? 0.0,
        cleanlinessLevel: _niveauProprete.round(),
        noiseTolerance: _toleranceBruit.round(),
        habits: List<String>.from(_habitudesSelectionnees),
      );
      final UserModel utilisateur = UserModel(
        uid: _uid!,
        name: _nomCtrl.text.trim(),
        firstname: _prenomCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _telCtrl.text.trim(),
        createdAt: DateTime.now(),
        studentProfile: profilEtudiant,
      );
      await _authService.enregistrerProfil(utilisateur);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => AccueilScreen(utilisateur: utilisateur)),
        );
      }
    } on Exception catch (e) {
      _afficherErreur(_formaterErreurFirebase(e.toString()));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formaterErreurFirebase(String erreur) {
    if (erreur.contains('email-already-in-use')) return 'Cette adresse email est déjà utilisée.';
    if (erreur.contains('weak-password')) return 'Le mot de passe doit contenir au moins 6 caractères.';
    if (erreur.contains('invalid-email')) return 'Adresse email invalide.';
    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    _telCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _construireEnTete(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [_construireEtape1(), _construireEtape2(), _construireEtape3()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construireEnTete() {
    const List<String> titresEtapes = ['Accès Rapide', 'Votre Situation', 'Profil de Vie'];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Mon Coloc',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E3A5F))),
            ],
          ),
          const SizedBox(height: 16),
          Text('Étape ${_etapeCourante + 1}/3 — ${titresEtapes[_etapeCourante]}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_etapeCourante + 1) / 3,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }

  // ÉTAPE 1 : Accès Rapide
  Widget _construireEtape1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _cleFormEtape1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Créez votre compte',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E3A5F))),
            const SizedBox(height: 4),
            const Text('Rejoignez la communauté Mon Coloc à Abidjan',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            const SizedBox(height: 24),
            _champTexte(controleur: _nomCtrl, label: 'Nom de famille', icone: Icons.person_outline,
              validateur: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer votre nom' : null),
            const SizedBox(height: 16),
            _champTexte(controleur: _prenomCtrl, label: 'Prénom', icone: Icons.badge_outlined,
              validateur: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer votre prénom' : null),
            const SizedBox(height: 16),
            _champTexte(controleur: _emailCtrl, label: 'Adresse email', icone: Icons.email_outlined,
              typeClavier: TextInputType.emailAddress,
              validateur: (v) {
                if (v == null || v.isEmpty) return 'Veuillez entrer votre email';
                if (!v.contains('@')) return 'Email invalide';
                return null;
              }),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mdpCtrl,
              obscureText: !_mdpVisible,
              decoration: _decorationChamp(
                label: 'Mot de passe',
                icone: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(_mdpVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF6B7280)),
                  onPressed: () => setState(() => _mdpVisible = !_mdpVisible),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Veuillez entrer un mot de passe';
                if (v.length < 6) return 'Minimum 6 caractères';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _decorationChamp(
                label: 'Numéro de téléphone', icone: Icons.phone_outlined, prefixText: '+225 '),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Veuillez entrer votre numéro';
                if (v.length < 8) return 'Numéro invalide';
                return null;
              },
            ),
            const SizedBox(height: 32),
            _boutonPrincipal(texte: 'Suivant', icone: Icons.arrow_forward_rounded,
              enChargement: _chargement, onPressed: _validerEtape1),
          ],
        ),
      ),
    );
  }

  // ÉTAPE 2 : Le Pivot
  Widget _construireEtape2() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Quelle est votre situation ?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E3A5F))),
          const SizedBox(height: 4),
          const Text('Cela nous permet de personnaliser votre expérience',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 36),
          _carteChoixSituation(
            valeur: 'no_housing', icone: Icons.search_rounded,
            titre: "Je n'ai pas de logement",
            description: 'Je cherche une colocation ou un logement abordable',
            couleur: const Color(0xFF2563EB)),
          const SizedBox(height: 16),
          _carteChoixSituation(
            valeur: 'has_housing', icone: Icons.home_rounded,
            titre: "J'ai déjà un logement",
            description: 'Je propose une chambre ou cherche un colocataire',
            couleur: const Color(0xFF059669)),
          const Spacer(),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _allerEtapePrecedente,
                icon: const Icon(Icons.arrow_back_rounded), label: const Text('Retour'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  foregroundColor: const Color(0xFF6B7280),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _boutonPrincipal(texte: 'Suivant',
                icone: Icons.arrow_forward_rounded, enChargement: false, onPressed: _validerEtape2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _carteChoixSituation({
    required String valeur, required IconData icone,
    required String titre, required String description, required Color couleur,
  }) {
    final bool sel = _situationChoisie == valeur;
    return GestureDetector(
      onTap: () => setState(() => _situationChoisie = valeur),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: sel ? couleur.withOpacity(0.08) : Colors.white,
          border: Border.all(color: sel ? couleur : const Color(0xFFE5E7EB), width: sel ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: sel ? couleur.withOpacity(0.15) : Colors.black.withOpacity(0.04),
            blurRadius: sel ? 12 : 6, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: sel ? couleur : couleur.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14)),
              child: Icon(icone, color: sel ? Colors.white : couleur, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: sel ? couleur : const Color(0xFF1E3A5F))),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ],
            )),
            if (sel) Icon(Icons.check_circle_rounded, color: couleur, size: 24),
          ],
        ),
      ),
    );
  }

  // ÉTAPE 3 : Profil de Vie
  Widget _construireEtape3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _cleFormEtape3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Votre profil de vie',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E3A5F))),
            const SizedBox(height: 4),
            const Text('Ces informations nous aident à trouver votre coloc idéal',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            const SizedBox(height: 24),

            // Dropdown École
            _sectionLabel('Votre école'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _ecoleChoisie,
              decoration: _decorationChamp(label: 'Sélectionnez votre école', icone: Icons.school_outlined),
              items: _listeEcoles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _ecoleChoisie = val),
            ),
            const SizedBox(height: 20),

            // Budget
            _sectionLabel('Budget maximum mensuel (FCFA)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _budgetCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _decorationChamp(label: 'Ex : 50000', icone: Icons.payments_outlined, suffixText: 'FCFA'),
              validator: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer un budget' : null,
            ),
            const SizedBox(height: 24),

            // Slider Propreté
            _sectionLabel('Niveau de propreté exigé'),
            const SizedBox(height: 4),
            _sousLabel('${_niveauProprete.round()}/5 — ${_labelPropreteParValeur(_niveauProprete.round())}'),
            Slider(value: _niveauProprete, min: 1, max: 5, divisions: 4,
              activeColor: const Color(0xFF2563EB), inactiveColor: const Color(0xFFE5E7EB),
              onChanged: (val) => setState(() => _niveauProprete = val)),
            const SizedBox(height: 16),

            // Slider Bruit
            _sectionLabel('Tolérance au bruit'),
            const SizedBox(height: 4),
            _sousLabel('${_toleranceBruit.round()}/5 — ${_labelBruitParValeur(_toleranceBruit.round())}'),
            Slider(value: _toleranceBruit, min: 1, max: 5, divisions: 4,
              activeColor: const Color(0xFF7C3AED), inactiveColor: const Color(0xFFE5E7EB),
              onChanged: (val) => setState(() => _toleranceBruit = val)),
            const SizedBox(height: 24),

            // FilterChips Habitudes
            _sectionLabel('Vos habitudes de vie'),
            const SizedBox(height: 4),
            const Text('Sélectionnez tout ce qui vous correspond',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _listeHabitudes.map((habitude) {
                final bool sel = _habitudesSelectionnees.contains(habitude);
                return FilterChip(
                  label: Text(habitude, style: TextStyle(
                    fontSize: 13, color: sel ? Colors.white : const Color(0xFF374151),
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                  selected: sel,
                  onSelected: (s) => setState(() => s
                    ? _habitudesSelectionnees.add(habitude)
                    : _habitudesSelectionnees.remove(habitude)),
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  side: BorderSide(color: sel ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _allerEtapePrecedente,
                  icon: const Icon(Icons.arrow_back_rounded), label: const Text('Retour'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    foregroundColor: const Color(0xFF6B7280),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _boutonPrincipal(texte: "Terminer l'inscription",
                  icone: Icons.check_rounded, enChargement: _chargement,
                  onPressed: _validerEtape3EtEnregistrer)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Widgets utilitaires
  Widget _champTexte({
    required TextEditingController controleur, required String label,
    required IconData icone, TextInputType typeClavier = TextInputType.text,
    String? Function(String?)? validateur,
  }) {
    return TextFormField(
      controller: controleur, keyboardType: typeClavier,
      decoration: _decorationChamp(label: label, icone: icone), validator: validateur);
  }

  InputDecoration _decorationChamp({
    required String label, required IconData icone,
    Widget? suffixIcon, String? prefixText, String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
      prefixIcon: Icon(icone, color: const Color(0xFF6B7280), size: 20),
      prefixText: prefixText, suffixText: suffixText, suffixIcon: suffixIcon,
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _boutonPrincipal({
    required String texte, required IconData icone,
    required bool enChargement, required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton.icon(
        onPressed: enChargement ? null : onPressed,
        icon: enChargement
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icone, size: 20),
        label: Text(enChargement ? 'Chargement...' : texte,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF93C5FD),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _sectionLabel(String texte) => Text(texte,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)));

  Widget _sousLabel(String texte) => Text(texte,
    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)));

  String _labelPropreteParValeur(int v) =>
    const {1: 'Détendu', 2: 'Correct', 3: 'Propre', 4: 'Très propre', 5: 'Irréprochable'}[v] ?? '';

  String _labelBruitParValeur(int v) =>
    const {1: 'Silence total', 2: 'Calme', 3: 'Modéré', 4: 'Animé', 5: 'Très bruyant OK'}[v] ?? '';
}
'@; [System.IO.File]::WriteAllText('d:\projets2\mon_coloc\lib\screens\auth\inscription_screen.dart', $content, [System.Text.Encoding]::UTF8)

$content = @'
// Écran d'accueil temporaire affiché après inscription réussie

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/inscription_screen.dart';

class AccueilScreen extends StatelessWidget {
  // Utilisateur connecté transmis depuis l'inscription
  final UserModel utilisateur;

  const AccueilScreen({super.key, required this.utilisateur});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mon Coloc', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        actions: [
          // Bouton de déconnexion
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await authService.seDeconnecter();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const InscriptionScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte de bienvenue
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.celebration_rounded, color: Colors.white, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Bienvenue, ${utilisateur.firstname} !',
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Votre profil a été créé avec succès.',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Récapitulatif du profil
            const Text('Récapitulatif de votre profil',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E3A5F))),
            const SizedBox(height: 12),

            _ligneInfo(icone: Icons.person_outline, label: 'Nom complet',
              valeur: '${utilisateur.firstname} ${utilisateur.name}'),
            _ligneInfo(icone: Icons.email_outlined, label: 'Email', valeur: utilisateur.email),
            _ligneInfo(icone: Icons.phone_outlined, label: 'Téléphone',
              valeur: '+225 ${utilisateur.phone}'),

            if (utilisateur.studentProfile != null) ...[
              const SizedBox(height: 8),
              _ligneInfo(
                icone: utilisateur.studentProfile!.situation == 'no_housing'
                    ? Icons.search_rounded : Icons.home_rounded,
                label: 'Situation',
                valeur: utilisateur.studentProfile!.situation == 'no_housing'
                    ? 'Cherche un logement' : 'A déjà un logement'),
              _ligneInfo(icone: Icons.school_outlined, label: 'École',
                valeur: utilisateur.studentProfile!.school),
              _ligneInfo(icone: Icons.payments_outlined, label: 'Budget max',
                valeur: '${utilisateur.studentProfile!.maxBudget.toStringAsFixed(0)} FCFA'),
              _ligneInfo(icone: Icons.clean_hands_outlined, label: 'Propreté',
                valeur: '${utilisateur.studentProfile!.cleanlinessLevel}/5'),
              _ligneInfo(icone: Icons.volume_up_outlined, label: 'Tolérance bruit',
                valeur: '${utilisateur.studentProfile!.noiseTolerance}/5'),
            ],

            const SizedBox(height: 24),

            // Message provisoire
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.construction_rounded, color: Color(0xFFD97706)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fonctionnalités en développement.\nLa prochaine étape : recherche de colocataires !',
                      style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Ligne d'information du profil
  Widget _ligneInfo({required IconData icone, required String label, required String valeur}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icone, color: const Color(0xFF2563EB), size: 18),
          const SizedBox(width: 12),
          Text('$label : ', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          Expanded(child: Text(valeur,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E3A5F)),
            overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
'@; [System.IO.File]::WriteAllText('d:\projets2\mon_coloc\lib\screens\home\accueil_screen.dart', $content, [System.Text.Encoding]::UTF8)

$content = @'
// Point d'entrée de l'application Mon Coloc
// Initialise Firebase et démarre le parcours d'inscription

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth/inscription_screen.dart';

void main() async {
  // Obligatoire avant toute initialisation asynchrone dans main()
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation de Firebase (requiert google-services.json sur Android
  // et GoogleService-Info.plist sur iOS)
  await Firebase.initializeApp();

  runApp(const MonColocApp());
}

class MonColocApp extends StatelessWidget {
  const MonColocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mon Coloc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // L'écran de démarrage est toujours l'inscription pour le MVP
      home: const InscriptionScreen(),
    );
  }
}
'@; [System.IO.File]::WriteAllText('d:\projets2\mon_coloc\lib\main.dart', $content, [System.Text.Encoding]::UTF8)
