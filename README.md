<h1 align="center">🏠 Mon-Coloc</h1>
<p align="center"><strong>Application mobile de recherche de colocations étudiantes</strong></p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Firestore-039BE5?style=for-the-badge&logo=firebase&logoColor=white" />
  <img src="https://img.shields.io/badge/REST_API-005571?style=for-the-badge" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />
</p>

---

## 📌 Contexte & problème résolu

De nombreux étudiants peinent à trouver une colocation adaptée à leur budget, leur zone géographique et leurs préférences de vie commune. **Mon-Coloc** centralise les annonces de colocation et met en relation les étudiants via une interface mobile simple et rapide.

---

## ✨ Fonctionnalités

- 🔍 Recherche et filtrage d'annonces de colocation (budget, ville, quartier)
- 📝 Publication d'une annonce en quelques étapes
- 👤 Authentification et gestion de profil utilisateur
- 💬 Mise en relation entre étudiants (contact / messagerie)
- ☁️ Synchronisation temps réel des données via Cloud Firestore
- 🔗 Intégration d'une API REST externe pour [préciser : ex. données de localisation / vérification]

---

## 🖼️ Aperçu de l'application

| Écran d'accueil | Détail d'une annonce | Publication |
|---|---|---|
| `[Capture d'écran 1]` | `[Capture d'écran 2]` | `[Capture d'écran 3]` |

---

## 🏗️ Architecture

Le projet suit les principes de la **Clean Architecture**, avec une séparation claire des responsabilités :

```
lib/
├── core/            # Constantes, thèmes, utilitaires partagés
├── data/             # Sources de données (Firestore, API REST), repositories
├── domain/          # Entités métier, cas d'usage (use cases)
├── presentation/     # UI, widgets, gestion d'état (screens, providers/bloc)
└── main.dart
```

**Choix techniques clés :**
- **Flutter/Dart** pour un développement cross-platform performant (iOS/Android)
- **Cloud Firestore** pour une base de données NoSQL en temps réel
- **API REST** pour l'intégration de services externes
- **Clean Architecture** pour un code testable, maintenable et évolutif
- Modélisation préalable en **UML** (diagrammes de classes et de séquence disponibles dans `/docs`)

---

## ⚙️ Installation

```bash
# Cloner le dépôt
git clone https://github.com/joelessoh2006-hue/Mon-Coloc.git
cd Mon-Coloc

# Installer les dépendances
flutter pub get

# Configurer Firebase
# Ajouter votre fichier google-services.json (Android) / GoogleService-Info.plist (iOS)

# Lancer l'application
flutter run
```

---

## 🗺️ Roadmap

- [ ] Système de notifications push
- [ ] Filtres de recherche avancés (géolocalisation)
- [ ] Messagerie intégrée en temps réel
- [ ] Tests unitaires et d'intégration

---

## 👨‍💻 Auteur

Développé par **Joel** dans le cadre de mon projet de fin de Licence en Génie Logiciel.

• [Email](mailto:joelessoh2006@gmail.com)
