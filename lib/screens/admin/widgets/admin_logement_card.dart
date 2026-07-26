import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Carte réutilisable pour afficher un logement en attente de validation dans le panel admin.
class AdminLogementCard extends StatelessWidget {
  final String logementId;
  final Map<String, dynamic> data;
  final Function(String) onApprouver;
  final Function(String, Map<String, dynamic>) onRejeter;
  final Function(List<String>) onAfficherMedia;

  const AdminLogementCard({
    super.key,
    required this.logementId,
    required this.data,
    required this.onApprouver,
    required this.onRejeter,
    required this.onAfficherMedia,
  });

  // Formate un montant avec des séparateurs de milliers.
  String _formatMontant(dynamic montant) {
    if (montant == null) return '0';
    final nombre = montant is int ? montant : int.tryParse(montant.toString()) ?? 0;
    final str = nombre.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  // Convertit un champ potentiellement List ou null en List<String>.
  List<String> _safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value.map((e) => e.toString()));
    if (value is String) return [value];
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final loyer = data['loyer'] ?? 0;
    final pieces = data['nombrePieces'] ?? 0;
    final commune = data['commune'] ?? 'Non spécifié';
    final quartier = data['quartier'] ?? '';
    final description = data['description'] ?? '';
    final photos = _safeStringList(
      data['logementPhotos'] ?? data['photos'] ?? data['imageUrls'] ?? [],
    );
    final datePublication = data['datePublication'] as Timestamp?;
    final dateStr = datePublication != null
        ? '${datePublication.toDate().day}/${datePublication.toDate().month}/${datePublication.toDate().year}'
        : 'Date inconnue';

    return Card(
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
            // En-tête : Statut badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hourglass_empty,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'En attente',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mini carousel des photos
            if (photos.isNotEmpty) ...[
              SizedBox(
                height: 140,
                child: PageView.builder(
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => onAfficherMedia(photos),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(photos[index]),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              // Pas de photos : bouton pour en ouvrir si jamais
              SizedBox(
                height: 100,
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () => onAfficherMedia(photos),
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Aucune photo'),
                  ),
                ),
              ),
            ],

            // Localisation
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 20,
                  color: Colors.red.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$commune${quartier.isNotEmpty ? ' — $quartier' : ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Loyer et pièces
            Row(
              children: [
                _InfoChip(
                  icon: Icons.monetization_on_rounded,
                  text: '${_formatMontant(loyer)} FCFA/mois',
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.meeting_room_rounded,
                  text: '$pieces pièce(s)',
                  color: Colors.blue.shade700,
                ),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onRejeter(logementId, data),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Rejeter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onApprouver(logementId),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Petit widget interne pour les badges d'information.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}