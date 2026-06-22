import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mon_coloc/screens/auth/login_screen.dart';
import 'package:mon_coloc/screens/home_screen.dart';
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
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [const Locale('fr', 'FR')],
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
      return const HomeScreen();
    }

    return LoginScreen(
      onConnexionReussie: () {
        // L'état d'authentification est géré par authStateChanges()
        // donc setState n'est pas nécessaire ici
      },
    );
  }
}

