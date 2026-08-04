import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mon_coloc/models/location_model.dart';
import 'package:mon_coloc/services/paystack_service.dart';
import 'package:mon_coloc/services/pdf_service.dart';

/// Écran de gestion des loyers et de la caution pour un étudiant.
class MesLoyersScreen extends StatefulWidget {
  const MesLoyersScreen({super.key});

  @override
  State<MesLoyersScreen> createState() => _MesLoyersScreenState();
}

class _MesLoyersScreenState extends State<MesLoyersScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final Future<LocationModel?> _locationFuture;

  @override
  void initState() {
    super.initState();
    _locationFuture = _fetchUserLocation();
  }

  /// Récupère la location active de l'étudiant.
  Future<LocationModel?> _fetchUserLocation() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final querySnapshot = await _firestore
        .collection('locations')
        .where('etudiantId', isEqualTo: user.uid)
        .where('statut', isEqualTo: 'active')
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return LocationModel.fromFirestore(querySnapshot.docs.first);
    }
    return null;
  }

  /// Lance le paiement de la caution.
  Future<void> _payerCaution(LocationModel location) async {
    final user = _auth.currentUser;
    if (user?.email == null) {
      _showErrorSnackBar('Email utilisateur introuvable pour le paiement.');
      return;
    }

    await PaystackService.lancerPaiement(
      context: context,
      emailEtudiant: user!.email!,
      montant: location.montantCaution.toDouble(),
      logementId: location.logementId,
      bailleurUid: location.bailleurId,
      etudiantUid: user.uid,
      typePaiement: 'caution',
      onSuccess: () async {
        // Mettre à jour le statut de la caution dans la location
        await _firestore.collection('locations').doc(location.id).update({
          'cautionPayee': true,
          'datePaiementCaution': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _showSuccessSnackBar('Paiement de la caution effectué avec succès !');
          // Rafraîchir l'écran
          setState(() {
            _locationFuture = _fetchUserLocation();
          });
        }
      },
    );
  }

  /// Lance le paiement d'un loyer mensuel.
  Future<void> _payerLoyer(
    LocationModel location,
    DocumentSnapshot echeanceDoc,
  ) async {
    final user = _auth.currentUser;
    if (user?.email == null) {
      _showErrorSnackBar('Email utilisateur introuvable pour le paiement.');
      return;
    }

    final echeanceData = echeanceDoc.data() as Map<String, dynamic>;
    final montant = (echeanceData['montant'] as num).toDouble();

    await PaystackService.lancerPaiement(
      context: context,
      emailEtudiant: user!.email!,
      montant: montant,
      logementId: location.logementId,
      bailleurUid: location.bailleurId,
      etudiantUid: user.uid,
      typePaiement: 'loyer_mensuel',
      onSuccess: () async {
        // Mettre à jour le statut de l'échéance
        await echeanceDoc.reference.update({
          'statut': 'paye',
          'datePaiement': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _showSuccessSnackBar('Paiement du loyer effectué avec succès !');
          // L'interface se mettra à jour grâce au StreamBuilder
        }
      },
    );
  }

  /// Télécharge le reçu d'une transaction.
  Future<void> _telechargerRecu(String typePaiement, String logementId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final transactionSnapshot = await _firestore
          .collection('transactions')
          .where('etudiantUid', isEqualTo: user.uid)
          .where('logementId', isEqualTo: logementId)
          .where('typePaiement', isEqualTo: typePaiement)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (transactionSnapshot.docs.isNotEmpty) {
        final transactionData = transactionSnapshot.docs.first.data();
        await PdfService.generateReceipt(transactionData: transactionData);
      } else {
        _showErrorSnackBar('Aucune transaction trouvée pour ce paiement.');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la récupération du reçu : $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes Loyers et Paiements')),
      body: FutureBuilder<LocationModel?>(
        future: _locationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text(
                "Impossible de charger les informations de la location.",
              ),
            );
          }

          final location = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildCautionCard(location),
              const SizedBox(height: 24),
              Text(
                'Échéances de Loyer',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(height: 20),
              _buildEcheancesList(location),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCautionCard(LocationModel location) {
    final cautionPayee = location.cautionPayee;
    final montantCaution = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    ).format(location.montantCaution);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Caution (Dépôt de garantie)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Montant : $montantCaution',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (cautionPayee)
              Row(
                children: [
                  const Chip(
                    label: Text('Caution réglée'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () =>
                        _telechargerRecu('caution', location.logementId),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Télécharger le reçu'),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _payerCaution(location),
                  icon: const Icon(Icons.payment_rounded),
                  label: const Text('Payer la caution'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEcheancesList(LocationModel location) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('locations')
          .doc(location.id)
          .collection('echeances')
          .orderBy('annee')
          .orderBy('mois')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Aucune échéance de loyer trouvée."));
        }

        final echeances = snapshot.data!.docs;

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: echeances.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final echeanceDoc = echeances[index];
            final data = echeanceDoc.data() as Map<String, dynamic>;
            final statut = data['statut'] as String? ?? 'en_attente';
            final mois = data['mois'] as int;
            final annee = data['annee'] as int;
            final montant = NumberFormat.currency(
              locale: 'fr_FR',
              symbol: 'FCFA',
              decimalDigits: 0,
            ).format(data['montant']);

            // Formater le mois/année
            final date = DateTime(annee, mois);
            final moisAnneeStr = DateFormat.yMMMM('fr_FR').format(date);

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                title: Text(
                  moisAnneeStr,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Montant : $montant'),
                trailing: statut == 'paye'
                    ? TextButton(
                        onPressed: () => _telechargerRecu(
                          'loyer_mensuel',
                          location.logementId,
                        ),
                        child: const Text('Reçu'),
                      )
                    : FilledButton(
                        onPressed: () => _payerLoyer(location, echeanceDoc),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                        ),
                        child: const Text('Payer'),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
