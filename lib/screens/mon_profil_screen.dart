import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:mon_coloc/screens/admin/admin_dashboard_screen.dart';
import 'package:mon_coloc/screens/etudiant/demandes_etudiant_screen.dart';
import 'package:mon_coloc/screens/auth/login_screen.dart';
import 'package:mon_coloc/services/user_service.dart';

/// Écran "Mon Profil" complet avec sections en accordéon.
/// Utilisable à la fois par les Étudiants et les Bailleurs.
/// Les sections spécifiques au matching (Section 2) ne s'affichent
/// que pour le rôle 'etudiant'.
class MonProfilScreen extends StatefulWidget {
  const MonProfilScreen({super.key});

  @override
  State<MonProfilScreen> createState() => _MonProfilScreenState();
}

class _MonProfilScreenState extends State<MonProfilScreen> {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  // Contrôleurs de formulaire
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _ecoleController = TextEditingController();
  final _filiereController = TextEditingController();
  final _biographieController = TextEditingController();
  final _budgetController = TextEditingController();
  final _zoneRechercheController = TextEditingController();

  // États dropdowns
  String? _typeLogement;

  // États booléens
  bool _fumeur = false;
  bool _besoinSilence = false;
  Proprete _proprete = Proprete.propre;
  int _niveauSociabilite = 3;

  // Données utilisateur
  UserModel? _utilisateur;
  bool _chargement = true;
  bool _sauvegardeEnCours = false;
  bool _televersementEnCours = false;
  String? _messageTeleversement;

  // Pour savoir si des modifications ont été faites
  bool _modificationsEffectuees = false;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _ecoleController.dispose();
    _filiereController.dispose();
    _biographieController.dispose();
    _budgetController.dispose();
    _zoneRechercheController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _chargement = false);
      return;
    }

    final user = await _userService.recupererUtilisateur(uid);
    if (mounted) {
      setState(() {
        _utilisateur = user;
        _chargement = false;
        if (user != null) {
          _initialiserChamps(user);
        }
      });
    }
  }

  void _initialiserChamps(UserModel user) {
    _nomController.text = user.nom;
    _prenomController.text = user.prenom;
    _ecoleController.text = user.ecoleUniversite;
    _filiereController.text = user.filiere ?? '';
    _biographieController.text = user.biographie ?? '';
    _budgetController.text = user.budgetMaxFCFA.toStringAsFixed(0);
    _zoneRechercheController.text = user.zoneRecherche ?? '';
    _typeLogement = user.typeLogement;
    _fumeur = user.fumeur;
    _besoinSilence = user.besoinSilence;
    _proprete = user.proprete;
    _niveauSociabilite = user.niveauSociabilite ?? 3;

    // Écouter les changements sur les champs
    _nomController.addListener(_marquerModification);
    _prenomController.addListener(_marquerModification);
    _ecoleController.addListener(_marquerModification);
    _filiereController.addListener(_marquerModification);
    _biographieController.addListener(_marquerModification);
    _budgetController.addListener(_marquerModification);
    _zoneRechercheController.addListener(_marquerModification);
  }

  void _marquerModification() {
    if (!_modificationsEffectuees) {
      setState(() => _modificationsEffectuees = true);
    }
  }

  // ---------------------------------------------------------------------------
  // SÉLECTION & TÉLÉVERSEMENT PHOTO DE PROFIL
  // ---------------------------------------------------------------------------
  Future<void> _choisirPhotoProfil() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;
      await _televerserPhotoProfil(image);
    } catch (e) {
      debugPrint('Erreur sélection photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection: $e')),
        );
      }
    }
  }

  Future<void> _televerserPhotoProfil(XFile image) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _televersementEnCours = true;
      _messageTeleversement = 'Téléversement de la photo…';
    });

    try {
      final url = await _userService.televerserPhotoProfil(
        uid: uid,
        imageFile: image,
      );
      // Mettre à jour Firestore
      await _userService.mettreAJourPartiel(
        uid: uid,
        donnees: {'photoUrl': url},
      );

      // Recharger les données utilisateur
      final user = await _userService.recupererUtilisateur(uid);
      if (mounted) {
        setState(() {
          _utilisateur = user;
          _televersementEnCours = false;
          _messageTeleversement = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo de profil mise à jour !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur téléversement photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
    // Le `finally` est déplacé ici pour s'exécuter après le try/catch
    if (mounted) {
      setState(() {
        _televersementEnCours = false;
        _messageTeleversement = null;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // SÉLECTION & TÉLÉVERSEMENT JUSTIFICATIF
  // ---------------------------------------------------------------------------
  Future<void> _choisirJustificatif() async {
    try {
      final XFile? doc = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (doc == null) return;
      await _televerserJustificatif(doc);
    } catch (e) {
      debugPrint('Erreur sélection justificatif: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection: $e')),
        );
      }
    }
  }

  Future<void> _televerserJustificatif(XFile doc) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _televersementEnCours = true;
      _messageTeleversement = 'Téléversement du justificatif…';
    });

    try {
      final url = await _userService.televerserJustificatif(
        uid: uid,
        docFile: doc,
      );
      // Mettre à jour Firestore
      await _userService.mettreAJourPartiel(
        uid: uid,
        donnees: {'justificatifUrl': url},
      );

      // Recharger
      final user = await _userService.recupererUtilisateur(uid);
      if (mounted) {
        setState(() {
          _utilisateur = user;
          _televersementEnCours = false;
          _messageTeleversement = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Justificatif téléversé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur téléversement justificatif: $e');
      if (mounted) {
        setState(() {
          _televersementEnCours = false;
          _messageTeleversement = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SAUVEGARDE
  // ---------------------------------------------------------------------------
  Future<void> _sauvegarder() async {
    final uid = _auth.currentUser?.uid;
    final user = _utilisateur;
    if (uid == null || user == null) return;

    setState(() => _sauvegardeEnCours = true);

    try {
      final donnees = <String, dynamic>{
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'ecoleUniversite': _ecoleController.text.trim(),
        'filiere': _filiereController.text.trim(),
        'biographie': _biographieController.text.trim(),
        'budgetMaxFCFA': double.tryParse(_budgetController.text.trim()) ?? 0,
        'zoneRecherche': _zoneRechercheController.text.trim(),
        'typeLogement': _typeLogement,
        'fumeur': _fumeur,
        'besoinSilence': _besoinSilence,
        'proprete': _proprete.name,
        'niveauSociabilite': _niveauSociabilite,
      };

      await _userService.mettreAJourPartiel(uid: uid, donnees: donnees);

      // Recharger
      final userActualise = await _userService.recupererUtilisateur(uid);
      if (mounted) {
        setState(() {
          _utilisateur = userActualise;
          _sauvegardeEnCours = false;
          _modificationsEffectuees = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur sauvegarde: $e');
      if (mounted) {
        setState(() => _sauvegardeEnCours = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // DÉCONNEXION
  // ---------------------------------------------------------------------------
  Future<void> _deconnexion() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            onConnexionReussie: () {
              // Callback appelé si l'utilisateur se re-connecte
            },
          ),
        ),
        (route) => false,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = _utilisateur;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mon Profil')),
        body: const Center(child: Text('Impossible de charger le profil.')),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Contenu principal
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- EN-TÊTE ---
                  _buildHeader(user),
                  const SizedBox(height: 24),

                  // --- Carte "Mes demandes" (Étudiant seulement) ---
                  if (user.role == 'etudiant') ...[
                    Card(
                      elevation: 0,
                      color: const Color(0xFFE8F5E9),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.assignment_turned_in_rounded,
                            color: Color(0xFF1E6B4E)),
                        title: const Text('Mes demandes de réservation',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text(
                            'Suivre mes réservations et payer les acomptes'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const DemandesEtudiantScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // --- SECTION 1 : Informations Personnelles & Académiques ---
                  _buildSectionInformations(user),
                  const SizedBox(height: 16),

                  // --- SECTION 2 : Critères & Habitudes (Étudiant seulement) ---
                  if (user.role == 'etudiant') ...[
                    _buildSectionCriteres(),
                    const SizedBox(height: 16),
                  ],

                  // --- SECTION 3 : Sécurité & Justificatifs ---
                  if (user.role != 'admin') ...[
                    _buildSectionSecurite(user),
                    const SizedBox(height: 16),
                  ],

                  // --- SECTION 4 : Actions ---
                  _buildSectionActions(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Overlay de téléversement
          if (_televersementEnCours)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 24),
                        Text(
                          _messageTeleversement ?? 'Traitement en cours…',
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EN-TÊTE
  // ---------------------------------------------------------------------------
  Widget _buildHeader(UserModel user) {
    final theme = Theme.of(context);
    final initiale = user.prenom.isNotEmpty
        ? user.prenom[0].toUpperCase()
        : user.nom.isNotEmpty
        ? user.nom[0].toUpperCase()
        : '?';

    return Column(
      children: [
        // Avatar
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? Text(
                      initiale,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            // Bouton appareil photo
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 3),
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt_rounded, size: 22),
                color: theme.colorScheme.onPrimary,
                onPressed: _choisirPhotoProfil,
                tooltip: 'Modifier la photo de profil',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Nom Prénom
        Text(
          '${user.prenom} ${user.nom}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),

        // Rôle avec badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: user.role == 'etudiant'
                ? Colors.blue.withOpacity(0.1) // Étudiant
                : user.role == 'bailleur'
                ? Colors.orange.withOpacity(0.1) // Bailleur
                : Colors.red.withOpacity(0.1), // Administrateur
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            user.role == 'etudiant'
                ? 'Étudiant'
                : user.role == 'bailleur'
                ? 'Bailleur'
                : 'Administrateur', // Texte pour l'administrateur
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: user.role == 'etudiant'
                  ? Colors.blue.shade700
                  : user.role == 'bailleur'
                  ? Colors.orange.shade700
                  : Colors.red.shade700, // Couleur pour l'administrateur
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 1 : Informations Personnelles & Académiques
  // ---------------------------------------------------------------------------
  Widget _buildSectionInformations(UserModel user) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        leading: Icon(Icons.person_rounded, color: Colors.blue.shade600),
        title: const Text(
          'Informations Personnelles',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: const Text('Nom, école, biographie…'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          const SizedBox(height: 8),

          // Nom
          _champTexte(
            controller: _nomController,
            label: 'Nom',
            icon: Icons.badge_rounded,
          ),
          const SizedBox(height: 12),

          // Prénom
          _champTexte(
            controller: _prenomController,
            label: 'Prénom',
            icon: Icons.badge_rounded,
          ),
          const SizedBox(height: 12),

          // École / Université & Filière (masqué pour admin)
          if (user.role != 'admin') ...[
            _champTexte(
              controller: _ecoleController,
              label: 'École / Université',
              icon: Icons.school_rounded,
            ),
            const SizedBox(height: 12),

            // Filière
            _champTexte(
              controller: _filiereController,
              label: "Filière d'études",
              icon: Icons.menu_book_rounded,
            ),
          ],
          const SizedBox(height: 12),

          // Biographie
          TextField(
            controller: _biographieController,
            decoration: InputDecoration(
              labelText: 'Courte biographie / présentation',
              prefixIcon: const Icon(Icons.description_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 2 : Critères & Habitudes (Matching - Étudiant seulement)
  // ---------------------------------------------------------------------------
  Widget _buildSectionCriteres() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        leading: Icon(Icons.tune_rounded, color: Colors.teal.shade600),
        title: const Text(
          'Critères & Habitudes',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: const Text('Pour le matching avec vos colocs'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          const SizedBox(height: 8),

          // Budget
          _champTexte(
            controller: _budgetController,
            label: 'Budget mensuel maximum (FCFA)',
            icon: Icons.monetization_on_rounded,
            typeClavier: TextInputType.number,
          ),
          const SizedBox(height: 12),

          // Zone de recherche
          _champTexte(
            controller: _zoneRechercheController,
            label: 'Zone de recherche (ex: Riviera, Angré)',
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: 12),

          // Type de logement
          DropdownButtonFormField<String>(
            initialValue: _typeLogement,
            decoration: InputDecoration(
              labelText: 'Type de logement souhaité',
              prefixIcon: const Icon(Icons.home_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('— Non spécifié —')),
              DropdownMenuItem(
                value: 'Appartement',
                child: Text('Appartement'),
              ),
              DropdownMenuItem(value: 'Studio', child: Text('Studio')),
              DropdownMenuItem(value: 'Chambre', child: Text('Chambre')),
              DropdownMenuItem(value: 'Villa', child: Text('Villa')),
              DropdownMenuItem(value: 'Duplex', child: Text('Duplex')),
            ],
            onChanged: (val) {
              setState(() {
                _typeLogement = val;
                _modificationsEffectuees = true;
              });
            },
          ),
          const SizedBox(height: 16),

          // Fumeur
          SwitchListTile(
            title: const Text('Fumeur'),
            subtitle: const Text('Est-ce que vous fumez ?'),
            secondary: Icon(
              Icons.smoking_rooms_rounded,
              color: _fumeur ? Colors.orange : Colors.grey,
            ),
            value: _fumeur,
            onChanged: (val) {
              setState(() {
                _fumeur = val;
                _modificationsEffectuees = true;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 4),

          // Besoin de silence
          SwitchListTile(
            title: const Text('Besoin de silence'),
            subtitle: const Text('Préférez-vous un environnement calme ?'),
            secondary: Icon(
              Icons.volume_mute_rounded,
              color: _besoinSilence ? Colors.indigo : Colors.grey,
            ),
            value: _besoinSilence,
            onChanged: (val) {
              setState(() {
                _besoinSilence = val;
                _modificationsEffectuees = true;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 4),

          // Niveau de propreté
          DropdownButtonFormField<Proprete>(
            initialValue: _proprete,
            decoration: InputDecoration(
              labelText: 'Niveau de propreté',
              prefixIcon: const Icon(Icons.cleaning_services_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: Proprete.tresPropre,
                child: Text('Très propre'),
              ),
              DropdownMenuItem(value: Proprete.propre, child: Text('Propre')),
              DropdownMenuItem(value: Proprete.moyen, child: Text('Moyen')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _proprete = val;
                  _modificationsEffectuees = true;
                });
              }
            },
          ),
          const SizedBox(height: 16),

          // Niveau de sociabilité
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_rounded, color: Colors.grey),
                  const SizedBox(width: 12),
                  const Text(
                    'Niveau de sociabilité',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final niveau = index + 1;
                  final isSelected = _niveauSociabilite == niveau;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _niveauSociabilite = niveau;
                        _modificationsEffectuees = true;
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.teal.shade100
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: Colors.teal, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$niveau',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.teal.shade800
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _niveauSociabilite <= 2
                      ? 'Plutôt réservé'
                      : _niveauSociabilite >= 4
                      ? 'Très sociable'
                      : 'Sociable',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 3 : Sécurité & Justificatifs
  // ---------------------------------------------------------------------------
  Widget _buildSectionSecurite(UserModel user) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: user.role == 'bailleur'
          ? _buildSectionSecuriteBailleur(user)
          : _buildSectionSecuriteEtudiant(user),
    );
  }

  /// Section sécurité pour les BAILLEURS (simplifiée)
  Widget _buildSectionSecuriteBailleur(UserModel user) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: user.estVerifie
          ? _buildBadgeVerifie()
          : _buildBadgeEnAttenteExamen(),
    );
  }

  /// Section sécurité pour les ÉTUDIANTS (avec upload)
  Widget _buildSectionSecuriteEtudiant(UserModel user) {
    final theme = Theme.of(context);
    const descriptionJustificatif =
        'Carte d\'étudiant, reçu d\'inscription ou certificat de scolarité';

    return ExpansionTile(
      initiallyExpanded: true,
      shape: const RoundedRectangleBorder(),
      collapsedShape: const RoundedRectangleBorder(),
      leading: Icon(Icons.verified_rounded, color: Colors.green.shade600),
      title: const Text(
        'Sécurité & Justificatifs',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: const Text('Statut du profil et documents'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Divider(),
        const SizedBox(height: 8),
        _buildBadgeVerifieEtudiant(user),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        const Text(
          'Documents justificatifs',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          'En tant que Étudiant : $descriptionJustificatif',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        if (user.justificatifUrl != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Justificatif téléversé',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _choisirJustificatif,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(
              user.justificatifUrl != null
                  ? 'Remplacer le justificatif'
                  : 'Téléverser un justificatif',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeVerifie() {
    return Row(
      children: [
        const Icon(Icons.verified_rounded, color: Colors.green, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profil vérifié',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
              Text(
                'Votre identité a été confirmée par l\'administrateur.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeEnAttenteExamen() {
    return Row(
      children: [
        const Icon(
          Icons.access_time_filled_rounded,
          color: Colors.orange,
          size: 32,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'En cours d\'examen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
              Text(
                'Vos documents ont bien été soumis et sont en cours d\'examen.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeVerifieEtudiant(UserModel user) {
    return Row(
      children: [
        Icon(
          user.estVerifie ? Icons.verified_rounded : Icons.access_time_rounded,
          color: user.estVerifie ? Colors.green : Colors.orange,
          size: 32,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.estVerifie
                    ? 'Profil vérifié'
                    : 'En attente de vérification',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: user.estVerifie
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
              Text(
                user.estVerifie
                    ? 'Votre identité a été confirmée.'
                    : 'Téléversez vos justificatifs pour être vérifié.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 4 : Actions
  // ---------------------------------------------------------------------------
  Widget _buildSectionActions() {
    final theme = Theme.of(context);
    final user = _utilisateur;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bouton Admin (visible uniquement pour le rôle 'admin')
        if (user?.role == 'admin') ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminDashboardScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.shield_rounded, size: 22),
              label: const Text(
                '🛡️ Accéder au Panel Admin',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Bouton Enregistrer
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _sauvegardeEnCours || _televersementEnCours
                ? null
                : _sauvegarder,
            icon: _sauvegardeEnCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              _sauvegardeEnCours
                  ? 'Sauvegarde en cours…'
                  : _modificationsEffectuees
                  ? 'Enregistrer les modifications'
                  : 'Sauvegarder le profil',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Bouton Déconnexion
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _deconnexion,
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'Se déconnecter',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CHAMP TEXTE RÉUTILISABLE
  // ---------------------------------------------------------------------------
  Widget _champTexte({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? typeClavier,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: typeClavier ?? TextInputType.text,
      textCapitalization: TextCapitalization.words,
    );
  }
}
