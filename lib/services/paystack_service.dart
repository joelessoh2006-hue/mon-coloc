import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';

class PaystackService {
  // Clé publique de test Paystack
  static const String _publicKey =
      'pk_test_991b516396fbcf1f58b4ed5c558fd90120f2663a';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lance le paiement Paystack pour un acompte de réservation ou un loyer mensuel
  static Future<void> lancerPaiement({
    required BuildContext context,
    required String emailEtudiant,
    required double montant, // Montant en FCFA
    required String logementId,
    required String bailleurUid,
    required String etudiantUid,
    required String typePaiement, // 'acompte_reservation' ou 'loyer_mensuel'
  }) async {
    final int amountInSubunits = (montant * 100).toInt();
    final String reference =
        'TRX_${typePaiement.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      await FlutterPaystackPlus.openPaystackPopup(
        publicKey: _publicKey,
        customerEmail: emailEtudiant,
        amount: amountInSubunits.toString(),
        reference: reference,
        currency: 'XOF', // Franc CFA
        onClosed: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Paiement annulé.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
        onSuccess: () async {
          // 1. Enregistrer la transaction dans Firestore
          await _firestore.collection('transactions').add({
            'referencePaystack': reference,
            'logementId': logementId,
            'etudiantUid': etudiantUid,
            'bailleurUid': bailleurUid,
            'montant': montant,
            'typePaiement': typePaiement,
            'statut': 'succes',
            'date': FieldValue.serverTimestamp(),
          });

          // 2. Mettre à jour l'état du logement si c'est une réservation
          if (typePaiement == 'acompte_reservation') {
            await _firestore.collection('logements').doc(logementId).update({
              'estReserve': true,
              'etudiantId': etudiantUid,
            });
          }

          // 3. Notification de succès
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Paiement effectué avec succès ! 🎉'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du paiement : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
