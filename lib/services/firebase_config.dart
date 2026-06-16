/// Configuration Firebase compatible Web + Mobile.
/// À remplacer par vos propres clés Firebase.
///
/// Pour générer automatiquement ce fichier :
///   1. Créez un projet Firebase (console.firebase.google.com)
///   2. Activez Authentication (Email/Mot de passe) et Firestore
///   3. Ajoutez une application Web (pour le support Chrome)
///   4. Exécutez : `flutterfire configure`
///
/// La commande `flutterfire configure` générera automatiquement
/// le fichier `firebase_options.dart` avec toutes les clés.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';

/// Initialise Firebase avec les options appropriées selon la plateforme.
///
/// Sur le Web, Firebase nécessite des options explicites (apiKey, authDomain, etc.)
/// Sur Mobile (Android/iOS), l'initialisation détecte automatiquement
/// les valeurs depuis google-services.json / GoogleService-Info.plist.
Future<void> initialiserFirebase() async {
  if (kIsWeb) {
    // ⚠️  REMPLACEZ CES VALEURS par celles de votre projet Firebase.
    // Allez dans Console Firebase → Paramètres du projet → Vos applications → Web
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyCo-NbIgCq-2GWtHlAN8Ii8KPuNljfrFWA',
        authDomain: 'mon-coloc-563a8.firebaseapp.com',
        projectId: 'mon-coloc-563a8',
        storageBucket: 'mon-coloc-563a8.firebasestorage.app',
        messagingSenderId: '592366840150',
        appId: '1:592366840150:web:a2491b52a1f02c35844ef7',
        measurementId: 'G-QK2V9XZGF1',
      ),
    );
  } else {
    // Mobile : les fichiers de config sont lus automatiquement
    // (google-services.json pour Android, GoogleService-Info.plist pour iOS)
    await Firebase.initializeApp();
  }
}
