import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Écran affichant la liste des demandes de réservation pour un bailleur.
///
/// Cet écran utilise un [StreamBuilder] pour écouter en temps réel les
/// modifications dans la collection 'demandes_reservation' de Firestore.
/// Il affiche uniquement les demandes où le 'bailleurId' correspond à l'UID
/// de l'utilisateur actuellement connecté.
class DemandesBailleurScreen extends StatefulWidget {
  const DemandesBailleurScreen({super.key});

  @override
  State<DemandesBailleurScreen> createState() => _DemandesBailleurScreenState();
}

class _DemandesBailleurScreenState extends State<DemandesBailleurScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  /// Met à jour le statut d'une demande de réservation dans Firestore.
  Future<void> _updateStatutDemande(
    String demandeId,
    String nouveauStatut,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('demandes_reservation')
          .doc(demandeId)
          .update({'statut': nouveauStatut});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Demande ${nouveauStatut == 'acceptee' ? 'acceptée' : 'refusée'} avec succès.',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demandes de Réservation')),
      body: _currentUser == null
          ? const Center(child: Text('Veuillez vous connecter.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('demandes_reservation')
                  .where(
                    'bailleurId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .orderBy('dateDemande', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SelectableText(
                        'Erreur : ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Aucune demande de réservation pour le moment.",
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final demandes = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: demandes.length,
                  itemBuilder: (context, index) {
                    final demande = demandes[index];
                    final data = demande.data() as Map<String, dynamic>;
                    final statut = data['statut'] as String? ?? 'inconnu';
                    final dateDemande = (data['dateDemande'] as Timestamp?)
                        ?.toDate();

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildDemandeContent(
                          demande,
                          data,
                          statut,
                          dateDemande,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildDemandeContent(
    DocumentSnapshot demande,
    Map<String, dynamic> data,
    String statut,
    DateTime? dateDemande,
  ) {
    // 1. Extraire directement les variables dénormalisées avec des fallbacks robustes.
    final stringTitre =
        data['logementTitre'] as String? ??
        data['logementTitle'] as String? ??
        data['titre'] as String? ??
        'Titre non disponible';

    final stringNom =
        data['etudiantNom'] as String? ??
        data['demandeurNom'] as String? ??
        data['studentName'] as String? ??
        'Étudiant inconnu';

    final stringTel =
        data['etudiantTelephone'] as String? ??
        data['telephone'] as String? ??
        data['phone'] as String? ??
        'Pas de numéro';

    final loyer = data['prix'] ?? data['loyer'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                stringTitre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StatutBadge(statut: statut),
          ],
        ),
        const Divider(height: 24),
        _buildInfoRow(
          icon: Icons.person_outline,
          label: 'Demandeur',
          value: stringNom,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.phone_outlined,
          label: 'Téléphone',
          value: stringTel,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.real_estate_agent_outlined,
          label: 'Loyer',
          value: '$loyer FCFA',
        ),
        const SizedBox(height: 16),
        if (dateDemande != null)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Demandé le: ${DateFormat.yMMMd('fr_FR').add_jm().format(dateDemande)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        if (statut == 'en_attente') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _updateStatutDemande(demande.id, 'refusee'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  child: const Text('Refuser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _updateStatutDemande(demande.id, 'acceptee'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E6B4E),
                  ),
                  child: const Text('Accepter'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

Widget _buildInfoRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: Colors.grey.shade600),
      const SizedBox(width: 12),
      Expanded(
        child: Text.rich(
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: Colors.grey.shade700),
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Un badge coloré pour afficher le statut d'une demande.
class _StatutBadge extends StatelessWidget {
  final String statut;

  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final Color couleur;
    final String texte;

    switch (statut) {
      case 'acceptee':
        couleur = Colors.green;
        texte = 'Acceptée';
        break;
      case 'refusee':
        couleur = Colors.red;
        texte = 'Refusée';
        break;
      case 'payee':
        couleur = const Color(0xFF1E6B4E); // Vert foncé, comme pour l'étudiant
        texte = 'Payée';
        break;
      default: // en_attente
        couleur = Colors.orange;
        texte = 'En attente';
    }

    return Chip(
      label: Text(
        texte,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: couleur,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
