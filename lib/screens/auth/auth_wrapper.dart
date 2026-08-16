import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/screens/auth/login_screen.dart';
import 'package:mon_coloc/screens/home_screen.dart';

/// Ce widget agit comme un aiguilleur principal pour l'application.
/// Il écoute en temps réel les changements d'état de l'authentification Firebase
/// et redirige l'utilisateur vers l'écran approprié.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Pendant que l'état de connexion est vérifié, on affiche un loader.
        // C'est crucial pour éviter un "flash" de l'écran de connexion au démarrage.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si l'utilisateur est connecté (snapshot a des données), on affiche HomeScreen.
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // Sinon, on affiche l'écran de connexion.
        return LoginScreen(onConnexionReussie: () {});
      },
    );
  }
}
