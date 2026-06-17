import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/screens/auth/login_screen.dart';
import 'package:mon_coloc/services/firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialiserFirebase();
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
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E6B4E),
        brightness: Brightness.light,
      ),
      home: const AuthGate(),
    );
  }
}

/// Widget qui écoute l'état d'authentification Firebase
/// et affiche LoginScreen ou HomePage selon que l'utilisateur est connecté
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _estConnecte = false;
  bool _initialisationTerminee = false;

  @override
  void initState() {
    super.initState();
    _verifierAuth();
  }

  Future<void> _verifierAuth() async {
    // Vérifier si un utilisateur est déjà connecté
    final user = _auth.currentUser;
    setState(() {
      _estConnecte = user != null;
      _initialisationTerminee = true;
    });

    // Écouter les changements d'état d'authentification
    _auth.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _estConnecte = user != null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialisationTerminee) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_estConnecte) {
      return const HomePage();
    }

    return LoginScreen(
      onConnexionReussie: () {
        // L'état d'authentification est géré par authStateChanges()
        // donc setState n'est pas nécessaire ici
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _inscriptionTerminee = false;

  @override
  Widget build(BuildContext context) {
    if (_inscriptionTerminee) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mon Coloc'),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 80, color: Colors.green),
              SizedBox(height: 24),
              Text(
                'Inscription réussie !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bienvenue dans la communauté Mon Coloc.',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Coloc'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work_rounded,
                size: 80, color: Colors.grey),
            SizedBox(height: 24),
            Text(
              'Bienvenue sur Mon Coloc',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Vous êtes connecté',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}