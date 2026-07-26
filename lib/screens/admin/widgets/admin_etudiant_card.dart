import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Carte réutilisable pour afficher un étudiant dans le panel admin.
class AdminEtudiantCard extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final Function(String, bool) onVerifier;
  final Function(String, String, String, bool) onBloquerDebloquer;
  final Function(String) onAfficherJustificatif;

  const AdminEtudiantCard({
    super.key,
    required this.uid,
    required this.data,
    required this.onVerifier,
    required this.onBloquerDebloquer,
    required this.onAfficherJustificatif,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nom = data['nom'] ?? '';
    final prenom = data['prenom'] ?? '';
    final email = data['email'] ?? '';
    final telephone = data['telephone'] ?? '';
    final ecole = data['ecoleUniversite'] ?? '';
    final filiere = data['filiere'] ?? '';
    final photoUrl = data['photoUrl'] as String?;
    final justificatifUrl = data['justificatifUrl'] as String?;
    final estVerifie = data['estVerifie'] as bool? ?? false;
    final estBloque = data['estBloque'] as bool? ?? false;
    final dateInscription = data['dateInscription'] as Timestamp?;
    final dateStr = dateInscription != null
        ? '${dateInscription.toDate().day}/${dateInscription.toDate().month}/${dateInscription.toDate().year}'
        : 'Date inconnue';

    final initiale = prenom.isNotEmpty
        ? prenom[0].toUpperCase()
        : nom.isNotEmpty
        ? nom[0].toUpperCase()
        : '?';

    return Opacity(
      opacity: estBloque ? 0.6 : 1.0,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: estVerifie ? Colors.green.shade200 : Colors.orange.shade200,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null
                        ? Text(
                            initiale,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$prenom $nom',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(estVerifie: estVerifie, estBloque: estBloque),
                ],
              ),
              const SizedBox(height: 12),
              if (telephone.isNotEmpty) ...[
                _InfoRow(icon: Icons.phone_rounded, text: 'Tél : $telephone'),
                const SizedBox(height: 4),
              ],
              if (ecole.isNotEmpty)
                _InfoRow(icon: Icons.school_rounded, text: 'École : $ecole'),
              if (filiere.isNotEmpty) ...[
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.menu_book_rounded,
                  text: 'Filière : $filiere',
                ),
              ],
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.calendar_today_rounded,
                text: 'Inscrit le $dateStr',
              ),
              if (justificatifUrl != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.document_scanner_rounded,
                      size: 18,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Pièce d\'identité',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => onAfficherJustificatif(justificatifUrl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Voir',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          onBloquerDebloquer(uid, nom, prenom, estBloque),
                      icon: Icon(
                        estBloque
                            ? Icons.lock_open_rounded
                            : Icons.block_rounded,
                        size: 18,
                      ),
                      label: Text(estBloque ? 'Débloquer' : 'Bloquer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: estBloque
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        side: BorderSide(
                          color: estBloque
                              ? Colors.green.shade300
                              : Colors.red.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (!estBloque) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onVerifier(uid, estVerifie),
                        icon: Icon(
                          estVerifie
                              ? Icons.undo_rounded
                              : Icons.verified_user_rounded,
                          size: 18,
                        ),
                        label: Text(estVerifie ? 'Rétirer' : 'Vérifier'),
                        style: FilledButton.styleFrom(
                          backgroundColor: estVerifie
                              ? Colors.orange.shade600
                              : Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool estVerifie;
  final bool estBloque;

  const _StatusBadge({required this.estVerifie, required this.estBloque});

  @override
  Widget build(BuildContext context) {
    if (estBloque) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'BLOQUÉ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.red.shade700,
          ),
        ),
      );
    }
    if (estVerifie) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '✓ Vérifié',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.green.shade700,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'En attente',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.orange.shade700,
        ),
      ),
    );
  }
}
