import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:mon_coloc/screens/admin/admin_dashboard_screen.dart';
import 'package:mon_coloc/screens/bailleur/add_logement_screen.dart';
import 'package:mon_coloc/screens/bailleur/bailleur_inbox_screen.dart';
import 'package:mon_coloc/screens/bailleur/bailleur_visits_screen.dart';
import 'package:mon_coloc/screens/bailleur/manage_logements_screen.dart';
import 'package:mon_coloc/screens/etudiant/decouvrir_screen.dart';
import 'package:mon_coloc/screens/etudiant/etudiant_messagerie_screen.dart';
import 'package:mon_coloc/screens/etudiant/logements_list_screen.dart';
import 'package:mon_coloc/screens/etudiant/mon_equipe_screen.dart';
import 'package:mon_coloc/screens/etudiant/mon_logement_screen.dart';
import 'package:mon_coloc/screens/mon_profil_screen.dart';
import 'package:mon_coloc/screens/auth/login_screen.dart';
import 'package:mon_coloc/services/chat_service.dart';

/// Écran d'accueil principal.
/// S'adapte dynamiquement selon le rôle de l'utilisateur (etudiant / bailleur).
/// Pour les étudiants, s'adapte aussi selon `aDejaUnLogement` :
/// - Si true : onglet "Logements" → "Mon logement"
/// - Si false : onglet "Logements" normal (liste des logements disponibles)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  /// Rôle de l'utilisateur : 'etudiant' ou 'bailleur'
  String? _role;

  /// Chargement en cours
  bool _chargement = true;

  /// Index de l'onglet actif (étudiant uniquement)
  int _ongletActif = 0;

  /// Index de l'onglet actif pour le bailleur
  int _ongletBailleurActif = 0;

  /// Nombre de conversations avec messages non lus
  int _nonLuCount = 0;

  /// Indique si l'étudiant connecté a déjà un logement
  bool _aDejaUnLogement = false;

  /// Étudiant chargé complètement
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _recupererRole();
  }

  /// Récupère le rôle de l'utilisateur depuis Firestore
  Future<void> _recupererRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _chargement = false);
        }
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _role = data['role'] as String? ?? 'etudiant';
        _aDejaUnLogement = data['aDejaUnLogement'] as bool? ?? false;

        // Construire l'UserModel complet
        _currentUser = UserModel.fromFirestore(doc);
      } else {
        _role = 'etudiant';
      }

      setState(() => _chargement = false);

      // Démarrer l'écoute des messages non lus si étudiant
      if (_role == 'etudiant') {
        _ecouterNonLus();
        _ecouterChangementsUtilisateur();
      }
    } catch (e) {
      debugPrint('Erreur récupération rôle : $e');
      if (mounted) {
        setState(() {
          _role = 'etudiant';
          _chargement = false;
        });
        _ecouterNonLus();
      }
    }
  }

  /// Écoute en temps réel les changements de l'utilisateur (pour mettre à jour aDejaUnLogement)
  void _ecouterChangementsUtilisateur() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _firestore.collection('users').doc(uid).snapshots().listen((doc) {
      if (!mounted || !doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final aDejaUnLogement = data['aDejaUnLogement'] as bool? ?? false;
      final shouldUpdateUser =
          _currentUser == null ||
          _currentUser!.estVerifie != (data['estVerifie'] as bool? ?? false) ||
          _currentUser!.justificatifUrl != (data['justificatifUrl'] as String?);

      if (aDejaUnLogement != _aDejaUnLogement || shouldUpdateUser) {
        setState(() {
          _aDejaUnLogement = aDejaUnLogement;
          if (shouldUpdateUser) {
            _currentUser = UserModel.fromFirestore(doc);
          }
        });
      }
    });
  }

  /// Écoute en temps réel toutes les conversations de l'utilisateur
  /// et calcule le nombre de non lues côté client.
  void _ecouterNonLus() {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      _chatService.ecouterConversations().listen((snapshot) {
        if (!mounted) return;
        int count = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final nonLuPar = data['nonLuPar'] as List<dynamic>?;
          if (nonLuPar != null && nonLuPar.contains(uid)) {
            count++;
          }
        }
        setState(() {
          _nonLuCount = count;
        });
      });
    } catch (_) {
      // Silencieux
    }
  }

  /// Déconnecte l'utilisateur
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

  @override
  Widget build(BuildContext context) {
    // Indicateur de chargement
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Interface selon le rôle
    if (_role == 'bailleur') {
      return _construireDashboardBailleur();
    }

    // Admin : redirige vers le panel admin
    if (_role == 'admin') {
      return _construireDashboardAdmin();
    }

    // Étudiant par défaut
    return _construireInterfaceEtudiant();
  }

  // ---------------------------------------------------------------------------
  // INTERFACE ÉTUDIANT
  // ---------------------------------------------------------------------------
  Widget _construireInterfaceEtudiant() {
    final pages = [
      _construirePageDecouvrir(),
      _construirePageMessagerie(),
      // Si l'étudiant a déjà un logement → "Mon logement", sinon → "Logements"
      _aDejaUnLogement
          ? _construirePageMonLogement()
          : _construirePageLogements(),
      _construirePageMonEquipe(),
      _construirePageMonProfil(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_shouldShowVerificationAlert) _buildVerificationAlert(),
            Expanded(child: pages[_ongletActif]),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _ongletActif,
        onTap: (index) => setState(() => _ongletActif = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_rounded),
            label: 'Découvrir',
          ),
          BottomNavigationBarItem(
            icon: _buildMessagerieIconWithBadge(),
            label: 'Messagerie',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              _aDejaUnLogement ? Icons.home_work_rounded : Icons.home_rounded,
            ),
            label: _aDejaUnLogement ? 'Mon logement' : 'Logements',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.group_rounded),
            label: 'Mon Équipe',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Mon Profil',
          ),
        ],
      ),
    );
  }

  /// Construit l'icône "Messagerie" avec un badge numérique Flutter affichant
  /// le nombre de messages non lus.
  Widget _buildMessagerieIconWithBadge() {
    return Badge(
      label: Text('${_nonLuCount > 99 ? '99+' : _nonLuCount}'),
      isLabelVisible: _nonLuCount > 0,
      child: const Icon(Icons.chat_rounded),
    );
  }

  bool get _shouldShowVerificationAlert {
    final user = _currentUser;
    return user != null &&
        user.role == 'etudiant' &&
        !user.estVerifie &&
        (user.justificatifUrl == null || user.justificatifUrl!.isEmpty);
  }

  Widget _buildVerificationAlert() {
    return Card(
      color: Colors.orange.shade50,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.orange.shade400, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "⚠️ Votre compte n'est pas encore vérifié. Veuillez téléverser votre justificatif pour soumettre votre dossier à l'administrateur.",
                style: TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirePageDecouvrir() {
    return const DecouvrirScreen();
  }

  Widget _construirePageMessagerie() {
    return const EtudiantMessagerieScreen();
  }

  Widget _construirePageMonEquipe() {
    return const MonEquipeScreen();
  }

  Widget _construirePageLogements() {
    return const LogementsListScreen();
  }

  Widget _construirePageMonLogement() {
    return const MonLogementScreen();
  }

  Widget _construirePageMonProfil() {
    return const MonProfilScreen();
  }

  // ---------------------------------------------------------------------------
  // INTERFACE BAILLEUR (DASHBOARD + ONGLETS)
  // ---------------------------------------------------------------------------
  Widget _construireDashboardBailleur() {
    final pages = [
      _construirePageBailleurAccueil(),
      const BailleurInboxScreen(),
      const BailleurVisitsScreen(),
    ];

    final titles = ['Espace Bailleur', 'Messagerie', 'Mes Visites'];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[_ongletBailleurActif],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Mon Profil',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MonProfilScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Se déconnecter',
            onPressed: _deconnexion,
          ),
        ],
      ),
      body: pages[_ongletBailleurActif],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _ongletBailleurActif,
        onTap: (index) => setState(() => _ongletBailleurActif = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: _buildBailleurMessagerieIconWithBadge(),
            label: 'Messagerie',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Visites',
          ),
        ],
      ),
    );
  }

  /// Construit l'icône "Messagerie" du bailleur avec un badge rouge
  /// indiquant le nombre de messages non lus.
  Widget _buildBailleurMessagerieIconWithBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.ecouterConversations(),
      builder: (context, snapshot) {
        final uid = _auth.currentUser?.uid;
        if (uid == null) return const Icon(Icons.chat_rounded);

        int count = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
            final nonLuPar = data['nonLuPar'] as List<dynamic>?;
            if (nonLuPar != null && nonLuPar.contains(uid)) {
              count++;
            }
          }
        }

        return Badge(
          label: Text('${count > 99 ? '99+' : count}'),
          isLabelVisible: count > 0,
          child: const Icon(Icons.chat_rounded),
        );
      },
    );
  }

  /// Page d'accueil du bailleur avec les actions principales.
  Widget _construirePageBailleurAccueil() {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Bienvenue dans votre espace',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gérez vos logements et suivez vos annonces en toute simplicité.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),

            // Bouton : Ajouter un nouveau logement
            SizedBox(
              width: double.infinity,
              child: _boutonAction(
                theme: theme,
                icone: Icons.add_home_rounded,
                titre: 'Ajouter un nouveau logement',
                description: 'Proposez un logement vérifié sur la plateforme',
                couleur: theme.colorScheme.primary,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddLogementScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Bouton : Gérer mes annonces
            SizedBox(
              width: double.infinity,
              child: _boutonAction(
                theme: theme,
                icone: Icons.business_center_rounded,
                titre: 'Gérer mes annonces',
                description: 'Consultez et modifiez vos annonces actives',
                couleur: const Color(0xFF7C3AED),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManageLogementsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INTERFACE ADMIN
  // ---------------------------------------------------------------------------
  Widget _construireDashboardAdmin() {    
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Pour ne pas avoir de bouton retour
        title: const Text( 
          '🛡️ Espace Admin',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.errorContainer,
        foregroundColor: theme.colorScheme.onErrorContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Mon Profil',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MonProfilScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Se déconnecter',
            onPressed: _deconnexion, // Appelle _auth.signOut()
          ),
        ],
      ),
      body: const AdminDashboardScreen(),
    );
  }

  Widget _boutonAction({
    required ThemeData theme,
    required IconData icone,
    required String titre,
    required String description,
    required Color couleur,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: couleur.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icone, size: 28, color: couleur),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 18, color: couleur),
            ],
          ),
        ),
      ),
    );
  }
}
