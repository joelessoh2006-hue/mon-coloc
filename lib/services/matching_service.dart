import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mon_coloc/models/user_model.dart';

/// Service de calcul d'affinité pour l'algorithme de matching entre étudiants.
///
/// Récupère tous les utilisateurs ayant le rôle 'etudiant',
/// exclut l'utilisateur connecté, calcule un score de compatibilité (0–100)
/// pour chacun et retourne la liste triée par score décroissant.
class MatchingService {
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  /// Récupère la liste des étudiants triés par score de compatibilité
  /// avec l'utilisateur connecté identifié par [currentUserId].
  ///
  /// Retourne une liste de profils (Map) enrichis d'un champ `scoreMatching`
  /// (entier entre 0 et 100), triée du score le plus élevé au plus faible.
  Future<List<Map<String, dynamic>>> getMatchedStudents(
      String currentUserId) async {
    // 1. Récupérer le profil de l'utilisateur connecté
    final currentUserDoc = await _usersCollection.doc(currentUserId).get();
    if (!currentUserDoc.exists) {
      return [];
    }
    final currentUser = UserModel.fromFirestore(currentUserDoc);

    // 2. Récupérer tous les utilisateurs avec le rôle 'etudiant'
    final querySnapshot = await _usersCollection
        .where('role', isEqualTo: 'etudiant')
        .get();

    // 3. Filtrer pour exclure l'utilisateur connecté et calculer les scores
    final List<Map<String, dynamic>> matchedStudents = [];

    for (final doc in querySnapshot.docs) {
      // Exclure l'utilisateur connecté
      if (doc.id == currentUserId) continue;

      final student = UserModel.fromFirestore(doc);
      final score = _calculerScoreAffinite(currentUser, student);

      // Récupérer les données brutes du document et ajouter le score
      final studentData = doc.data() as Map<String, dynamic>;
      studentData['id'] = doc.id;
      studentData['scoreMatching'] = score;
      matchedStudents.add(studentData);
    }

    // 4. Trier par score décroissant
    matchedStudents.sort((a, b) =>
        (b['scoreMatching'] as int).compareTo(a['scoreMatching'] as int));

    return matchedStudents;
  }

  /// Calcule le score d'affinité (0–100) entre l'utilisateur connecté [current]
  /// et un autre étudiant [other].
  ///
  /// Barème :
  ///   - Même école/université           → +40%
  ///   - Budget compatible (≤ 20k FCFA)   → +30%
  ///   - Même statut fumeur               → +10%
  ///   - Même besoin de silence           → +10%
  ///   - Même acceptation de la mixité    → +10%
  ///   -----------------------------------------
  ///   Total                              → 100%
  int _calculerScoreAffinite(UserModel current, UserModel other) {
    int score = 0;

    // 1. Même École/Université (+40%)
    if (current.ecoleUniversite.isNotEmpty &&
        other.ecoleUniversite.isNotEmpty &&
        current.ecoleUniversite.trim().toLowerCase() ==
            other.ecoleUniversite.trim().toLowerCase()) {
      score += 40;
    }

    // 2. Compatibilité Budget (+30%)
    // Si l'un des deux budgets est 0 ou négatif, on considère que le critère
    // ne peut pas être évalué (profil incomplet).
    if (current.budgetMaxFCFA > 0 && other.budgetMaxFCFA > 0) {
      final difference = (current.budgetMaxFCFA - other.budgetMaxFCFA).abs();
      if (difference <= 20000) {
        score += 30;
      }
    }

    // 3. Habitudes de vie (3 × 10% = 30%)
    // 3a. Même statut fumeur (+10%)
    if (current.fumeur == other.fumeur) {
      score += 10;
    }

    // 3b. Même besoin de silence (+10%)
    if (current.besoinSilence == other.besoinSilence) {
      score += 10;
    }

    // 3c. Même acceptation de la mixité (+10%)
    if (current.accepteMixite == other.accepteMixite) {
      score += 10;
    }

    return score;
  }
}