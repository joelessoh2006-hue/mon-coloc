import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mon_coloc/services/paystack_service.dart';

/// Écran affichant la liste des demandes de réservation pour un étudiant.
///
/// Cet écran utilise un [StreamBuilder] pour écouter en temps réel les
/// modifications dans la collection 'demandes_reservation' de Firestore.
/// Il affiche uniquement les demandes où le 'etudiantId' correspond à l'UID
/// de l'utilisateur actuellement connecté.
class DemandesEtudiantScreen extends StatefulWidget {
  const DemandesEtudiantScreen({super.key});

  @override
  State<DemandesEtudiantScreen> createState() => _DemandesEtudiantScreenState();
}

class _DemandesEtudiantScreenState extends State<DemandesEtudiantScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  /// Lance le processus de paiement de l'acompte via Paystack.
  Future<void> _payerAcompte(Map<String, dynamic> demandeData) async {
    if (_currentUser?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de récupérer votre email pour le paiement.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final loyer = (demandeData['prix'] as num?)?.toDouble() ?? 0.0;
    final acompte = loyer * 0.30;

    await PaystackService.lancerPaiement(
      context: context,
      emailEtudiant: _currentUser!.email!,
      montant: acompte,
      logementId: demandeData['logementId'] as String,
      bailleurUid: demandeData['bailleurId'] as String,
      etudiantUid: _currentUser!.uid,
      typePaiement: 'acompte_reservation',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes Demandes')),
      body: _currentUser == null
          ? const Center(child: Text('Veuillez vous connecter.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore
                  .instance //
                  .collection('demandes_reservation')
                  .where('etudiantId', isEqualTo: _currentUser!.uid)
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
                      "Vous n'avez fait aucune demande de réservation.",
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
                                    'Titre inconnu',
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
                                    'Bailleur : ${data['nomBailleur'] ?? 'Bailleur'}',
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Loyer : ${data['prix'] ?? 0} FCFA'),
                                ],
                              ),
                            ),
                            if (dateDemande != null)
                              Text(
                                'Demandé le: ${DateFormat.yMMMd('fr_FR').add_jm().format(dateDemande)}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            if (statut == 'acceptee') ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => _payerAcompte(data),
                                  icon: const Icon(Icons.credit_card),
                                  label: const Text("Payer l'acompte"),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E6B4E),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
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
