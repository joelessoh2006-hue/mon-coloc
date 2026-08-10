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
  /// [filtrerParStatutLogement] : si fourni, filtre les étudiants selon qu'ils
  /// ont déjà un logement (true) ou en cherchent un (false).
  ///
  /// Retourne une liste de profils (Map) enrichis d'un champ `scoreMatching`
  /// (entier entre 0 et 100), triée du score le plus élevé au plus faible.
  Future<List<Map<String, dynamic>>> getMatchedStudents(
      String currentUserId,
      {bool? filtrerParStatutLogement}) async {
    // 1. Récupérer le profil de l'utilisateur connecté
    final currentUserDoc = await _usersCollection.doc(currentUserId).get();
    if (!currentUserDoc.exists) {
      return [];
    }
    final currentUser = UserModel.fromFirestore(currentUserDoc);

    // 2. Récupérer les IDs des étudiants déjà en équipe ou en recherche active
    final Set<String> membresInTeams = {};
    final conversationsCollection =
        FirebaseFirestore.instance.collection('conversations');

    // Équipes validées
    final acceptedTeamsSnapshot =
        await conversationsCollection.where('demandeStatut', isEqualTo: 'accepte').get();
    for (final doc in acceptedTeamsSnapshot.docs) {
      final data = doc.data();
      final membres = List<String>.from(data['membres'] ?? []);
      membresInTeams.addAll(membres);
    }

    // Équipes en recherche active
    final searchingTeamsSnapshot = await conversationsCollection
        .where('rechercheColocActive', isEqualTo: true)
        .get();
    for (final doc in searchingTeamsSnapshot.docs) {
      final data = doc.data();
      final membres = List<String>.from(data['membres'] ?? []);
      membresInTeams.addAll(membres);
    }

    // 2. Récupérer tous les étudiants vérifiés
    final querySnapshot = await _usersCollection
        .where('role', isEqualTo: 'etudiant')
        .where('estVerifie', isEqualTo: true)
        .get();

    // 3. Filtrer pour exclure l'utilisateur connecté, appliquer filtre statut logement, et calculer les scores
    final List<Map<String, dynamic>> matchedStudents = [];

    for (final doc in querySnapshot.docs) {
      // Exclure l'utilisateur connecté
      if (doc.id == currentUserId) continue;

      // Exclure les étudiants déjà en équipe
      if (membresInTeams.contains(doc.id)) continue;

      // Appliquer le filtre optionnel sur aDejaUnLogement
      // Utilisation sécurisée : on vérifie d'abord si le champ existe via data()
      // pour éviter l'erreur "Bad state: field does not exist" sur les anciens profils
      if (filtrerParStatutLogement != null) {
        final data = doc.data() as Map<String, dynamic>?;
        final bool aDejaUnLogement = data?.containsKey('aDejaUnLogement') == true
            ? data!['aDejaUnLogement'] == true
            : false;
        if (aDejaUnLogement != filtrerParStatutLogement) continue;
      }

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

  /// Calcule le score d'affinité (0–100) entre deux utilisateurs spécifiques.
  Future<int> calculerScoreDetaille(String user1Id, String user2Id) async {
    final user1Doc = await _usersCollection.doc(user1Id).get();
    final user2Doc = await _usersCollection.doc(user2Id).get();

    if (!user1Doc.exists || !user2Doc.exists) {
      return 0;
    }

    final user1 = UserModel.fromFirestore(user1Doc);
    final user2 = UserModel.fromFirestore(user2Doc);

    return _calculerScoreAffinite(user1, user2);
  }

  /// Calcule le score d'affinité moyen entre l'utilisateur connecté
  /// et les autres membres d'une équipe.
  Future<int> calculerScoreMoyenEquipe(
      String currentUserId, List<String> equipeMembresIds) async {
    final currentUserDoc = await _usersCollection.doc(currentUserId).get();
    if (!currentUserDoc.exists) {
      return 0;
    }
    final currentUser = UserModel.fromFirestore(currentUserDoc);

    int totalScore = 0;
    int count = 0;

    for (final memberId in equipeMembresIds) {
      if (memberId == currentUserId) continue; // Ne pas se matcher avec soi-même
      final memberDoc = await _usersCollection.doc(memberId).get();
      if (memberDoc.exists) {
        final member = UserModel.fromFirestore(memberDoc);
        totalScore += _calculerScoreAffinite(currentUser, member);
        count++;
      }
    }
    return count > 0 ? (totalScore / count).round() : 0;
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