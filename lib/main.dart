import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mon_coloc/screens/auth/auth_wrapper.dart';
import 'package:mon_coloc/services/firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialiserFirebase();
  // Configurer la persistance locale pour le Web (et autres plateformes)
  // Ceci permet à l'utilisateur de rester connecté après un rechargement.
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  runApp(const MonColocApp());
}

class MonColocApp extends StatelessWidget {
  // MyApp dans la demande, mais MonColocApp dans le code
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
      home: const AuthWrapper(),
    );
  }
}
