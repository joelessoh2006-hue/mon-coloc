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
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                data['titreLogement'] as String? ??
                                    'Titre non disponible',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: _StatutBadge(statut: statut),
                            ),
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Demandeur : ${data['prenomEtudiant'] ?? ''} ${data['nomEtudiant'] ?? ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Téléphone : ${data['telephoneEtudiant'] ?? 'Pas de numéro'}',
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Loyer : ${data['prix'] ?? data['loyer'] ?? 0} FCFA',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (dateDemande != null)
                              Text(
                                'Demandé le: ${DateFormat.yMMMd('fr_FR').add_jm().format(dateDemande)}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            if (statut == 'en_attente') ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _updateStatutDemande(
                                      demande.id,
                                      'refusee',
                                    ),
                                    child: const Text(
                                      'Refuser',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () => _updateStatutDemande(
                                      demande.id,
                                      'acceptee',
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E6B4E),
                                    ),
                                    child: const Text('Accepter'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
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
