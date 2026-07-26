import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Carte réutilisable pour afficher un bailleur en attente de validation.
class AdminBailleurCard extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final Function(String) onApprouver;
  final Function(String, String, String, bool) onBloquerDebloquer;
  final Function(String) onAfficherJustificatif;

  const AdminBailleurCard({
    super.key,
    required this.uid,
    required this.data,
    required this.onApprouver,
    required this.onBloquerDebloquer,
    required this.onAfficherJustificatif,
  });

  List<String> _safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value.map((e) => e.toString()));
    if (value is String) return [value];
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nom = data['nom'] ?? '';
    final prenom = data['prenom'] ?? '';
    final email = data['email'] ?? '';
    final estBloque = data['estBloque'] as bool? ?? false;
    final dateInscription = data['dateInscription'] as Timestamp?;
    final dateStr = dateInscription != null
        ? '${dateInscription.toDate().day}/${dateInscription.toDate().month}/${dateInscription.toDate().year}'
        : 'Date inconnue';

    final initiale = (prenom as String).isNotEmpty
        ? prenom[0].toUpperCase()
        : (nom as String).isNotEmpty
            ? nom[0].toUpperCase()
            : '?';

    final Map<String, String> piecesJustificatives = {};
    if (data['justificatifUrl'] is String &&
        (data['justificatifUrl'] as String).isNotEmpty) {
      piecesJustificatives['Justificatif (CNI)'] = data['justificatifUrl'];
    }
    if (data['cniUrl'] is String && (data['cniUrl'] as String).isNotEmpty) {
      piecesJustificatives['CNI'] = data['cniUrl'];
    }
    if (data['titreProprieteUrl'] is String &&
        (data['titreProprieteUrl'] as String).isNotEmpty) {
      piecesJustificatives['Titre de propriété'] = data['titreProprieteUrl'];
    }
    final documentsUrls = _safeStringList(data['documentsUrls']);
    for (var i = 0; i < documentsUrls.length; i++) {
      piecesJustificatives['Document ${i + 1}'] = documentsUrls[i];
    }

    return Opacity(
      opacity: estBloque ? 0.6 : 1.0,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.orange.shade200),
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
                    backgroundImage: data['photoUrl'] is String
                        ? NetworkImage(data['photoUrl'])
                        : null,
                    child: data['photoUrl'] == null
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
                  _StatusBadge(
                    estVerifie: data['estVerifie'] as bool? ?? false,
                    estBloque: estBloque,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (data['telephone'] != null && data['telephone'].isNotEmpty) ...[
                _InfoRow(icon: Icons.phone_rounded, text: 'Tél : ${data['telephone']}'),
                const SizedBox(height: 4),
              ],
              _InfoRow(icon: Icons.calendar_today_rounded, text: 'Inscrit le $dateStr'),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              const Text(
                'Pièces justificatives',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (piecesJustificatives.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Aucun document fourni',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...piecesJustificatives.entries.map(
                  (entry) => _JustificatifRow(
                    label: entry.key,
                    url: entry.value,
                    onTap: () => onAfficherJustificatif(entry.value),
                  ),
                ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onBloquerDebloquer(uid, nom, prenom, estBloque),
                      icon: Icon(
                        estBloque ? Icons.lock_open_rounded : Icons.block_rounded,
                        size: 18,
                      ),
                      label: Text(estBloque ? 'Débloquer' : 'Bloquer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: estBloque ? Colors.green.shade700 : Colors.red.shade700,
                        side: BorderSide(
                          color: estBloque ? Colors.green.shade300 : Colors.red.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (!estBloque && !(data['estVerifie'] as bool? ?? false)) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onApprouver(uid),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approuver'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
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

class _JustificatifRow extends StatelessWidget {
  final String label;
  final String url;
  final VoidCallback onTap;

  const _JustificatifRow({required this.label, required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.document_scanner_rounded, size: 18, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_rounded, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Text('Voir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                ],
              ),
            ),
          ),
        ],
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
          child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
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
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
        child: Text('BLOQUÉ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
      );
    }
    if (estVerifie) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
        child: Text('✓ Vérifié', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
      child: Text('En attente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
    );
  }
}