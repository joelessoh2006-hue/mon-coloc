# Mon-Coloc

Application mobile de recherche de colocations étudiantes, développée avec Flutter et Firebase.

## Contexte

Trouver une colocation adaptée à son budget, sa zone géographique et ses préférences peut être difficile. Mon-Coloc vise à regrouper les annonces et à faciliter les échanges entre étudiants.

## Fonctionnalités

- Recherche et filtrage d’annonces par budget et localisation
- Publication d’annonces de logement
- Authentification et gestion de profil
- Échanges entre utilisateurs
- Synchronisation des données avec Cloud Firestore

## Captures d’écran

| Authentification | Détail d’une annonce | Publication d’une annonce |
|---|---|---|
| <img width="180" alt="Écran d’authentification" src="https://github.com/user-attachments/assets/f1da0ec7-ac97-4313-80dd-ead98672ac74" /> | <img width="180" alt="Détail d’une annonce" src="https://github.com/user-attachments/assets/c657eea3-d356-4988-90a3-a0d5f5840dd5" /> | <img width="180" alt="Écran de publication d’une annonce" src="https://github.com/user-attachments/assets/c5efdda9-e71e-4c92-8754-82836b01e058" /> |

## Technologies

- **Flutter et Dart** pour l’application mobile
- **Firebase Authentication** pour l’authentification
- **Cloud Firestore** pour les données
- **Firebase Storage** pour le stockage de fichiers

## Organisation du code

Le code de l’application se trouve dans `lib/`. Il est organisé autour des écrans, des modèles et des services, avec `main.dart` comme point d’entrée.

## Installation

1. Cloner le dépôt et ouvrir le dossier du projet :

   ```bash
   git clone https://github.com/joelessoh2006-hue/mon-coloc.git
   cd mon-coloc
   ```

2. Installer Flutter, puis récupérer les dépendances :

   ```bash
   flutter pub get
   ```

3. Configurer un projet Firebase et ajouter les fichiers de configuration pour les plateformes ciblées. Ne publiez pas de clés privées ni de fichiers contenant des secrets.

4. Démarrer l’application :

   ```bash
   flutter run
   ```

## Auteur

Joel Essoh — projet réalisé dans le cadre de la Licence en Génie logiciel à HEC Abidjan.

[Me contacter par email](mailto:joelessoh2006@gmail.com)
