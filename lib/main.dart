import 'package:cloud_firestore/cloud_firestore.dart';
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
/// et affiche LoginScreen ou HomePage selon que l'utilisateur est connecté.
/// Vérifie également si le compte n'est pas bloqué (estBloque == true).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _estConnecte = false;
  bool _initialisationTerminee = false;
  bool _estBloque = false;
  bool _verificationBloqueEnCours = false;

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

    // Si connecté, vérifier le statut de blocage
    if (user != null) {
      await _verifierStatutBlocage(user.uid);
    }

    // Écouter les changements d'état d'authentification
    _auth.authStateChanges().listen((User? user) async {
      if (mounted) {
        setState(() {
          _estConnecte = user != null;
        });
      }
      // Vérifier le blocage à chaque (re)connexion
      if (user != null && mounted) {
        await _verifierStatutBlocage(user.uid);
      } else if (mounted) {
        setState(() {
          _estBloque = false;
        });
      }
    });
  }

  /// Vérifie dans Firestore si l'utilisateur est bloqué (estBloque == true).
  Future<void> _verifierStatutBlocage(String uid) async {
    if (_verificationBloqueEnCours) return;
    _verificationBloqueEnCours = true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final bloque = data['estBloque'] as bool? ?? false;
        if (mounted) {
          setState(() {
            _estBloque = bloque;
          });
          // Si l'utilisateur est bloqué, le déconnecter après un court délai
          if (bloque) {
            await Future.delayed(const Duration(seconds: 1));
            await _auth.signOut();
            if (mounted) {
              setState(() {
                _estConnecte = false;
                _estBloque = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '⚠️ Votre compte a été suspendu. Contactez l\'administrateur.',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      // En cas d'erreur de lecture, on laisse passer
      debugPrint('Erreur vérification blocage: $e');
    } finally {
      _verificationBloqueEnCours = false;
    }
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

    if (_estBloque) {
      // Écran de compte bloqué (affiché pendant la déconnexion)
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.gpp_bad_rounded,
                  size: 80,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Compte suspendu',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Votre compte a été suspendu par l\'administration. '
                  'Veuillez contacter le support pour plus d\'informations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
            ),
          ),
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

