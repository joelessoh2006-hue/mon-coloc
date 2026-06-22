import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mon_coloc/models/visite_model.dart';
import 'package:mon_coloc/services/visite_service.dart';

/// Écran de gestion des demandes de visite pour le bailleur.
class BailleurVisitsScreen extends StatefulWidget {
  const BailleurVisitsScreen({super.key});

  @override
  State<BailleurVisitsScreen> createState() => _BailleurVisitsScreenState();
}

class _BailleurVisitsScreenState extends State<BailleurVisitsScreen> {
  final VisiteService _visiteService = VisiteService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Utilisateur non connecté'));
    }

    return Scaffold(
      appBar: null,
      body: StreamBuilder<QuerySnapshot>(
        stream: _visiteService.ecouterVisitesBailleur(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Erreur : ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final visitesDocs = snapshot.data?.docs ?? [];

          if (visitesDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune demande de visite',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Les demandes de visite des étudiants apparaîtront ici',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }

          // Trier les visites : en_attente d'abord, puis par date
          final visites = visitesDocs.map((doc) {
            return VisiteModel.fromFirestore(doc);
          }).toList();

          visites.sort((a, b) {
            // Les en_attente en premier
            if (a.status == 'en_attente' && b.status != 'en_attente') return -1;
            if (a.status != 'en_attente' && b.status == 'en_attente') return 1;
            // Puis par date de création décroissante
            return b.creeLe.compareTo(a.creeLe);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: visites.length,
            itemBuilder: (context, index) {
              return _buildVisiteCard(visites[index]);
            },
          );
        },
      ),
    );
  }

  /// Construit une carte pour une demande de visite.
  Widget _buildVisiteCard(VisiteModel visite) {
    final theme = Theme.of(context);
    final dateFormatee = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(visite.dateVisite);
    final heureFormatee = DateFormat('HH:mm').format(visite.dateVisite);
    final isEnAttente = visite.status == 'en_attente';
    final isConfirme = visite.status == 'confirme';
    final isRefuse = visite.status == 'refuse';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (isConfirme) {
      statusColor = const Color(0xFF2E7D32);
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Confirmée';
    } else if (isRefuse) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_rounded;
      statusLabel = 'Refusée';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule_rounded;
      statusLabel = 'En attente';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isEnAttente
              ? Colors.orange.withOpacity(0.3)
              : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : étudiant + statut
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visite.studentName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visite.logementTitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Date et heure de la visite
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$dateFormatee à $heureFormatee',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Boutons d'action (uniquement si en_attente)
            if (isEnAttente) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _accepterVisite(visite),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Accepter'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _refuserVisite(visite),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Refuser'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Accepte la visite et envoie un message automatique.
  Future<void> _accepterVisite(VisiteModel visite) async {
    try {
      await _visiteService.accepterVisite(
        visiteId: visite.id,
        studentId: visite.studentId,
        logementTitle: visite.logementTitle,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Visite acceptée ! Un message a été envoyé à l\'étudiant.'),
                ),
              ],
            ),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Refuse la visite.
  Future<void> _refuserVisite(VisiteModel visite) async {
    try {
      await _visiteService.refuserVisite(visite.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de visite refusée.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}