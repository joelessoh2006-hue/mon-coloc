import 'dart:js_interop';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:mon_coloc/services/pdf_service.dart';

@JS('paystackPopUp')
external void paystackPopUp(
  JSString key,
  JSString email,
  JSNumber amount,
  JSString ref,
  JSString plan,
  JSString currency,
  JSFunction onClose,
  JSFunction onSuccess,
);

class PaystackService {
  // Clé publique de test Paystack
  static const String _publicKey =
      'pk_test_991b516396fbcf1f58b4ed5c558fd90120f2663a';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lance le paiement Paystack et gère les mises à jour Firestore post-paiement.
  static Future<void> lancerPaiement({
    required BuildContext context,
    required String emailEtudiant,
    required double montant, // Montant en FCFA
    required String logementId,
    required String bailleurUid,
    required String etudiantUid,
    required String
    typePaiement, // 'acompte_reservation', 'caution', 'loyer_mensuel'
    String? locationId, // Requis pour 'caution' et 'loyer_mensuel'
    String? echeanceId, // Requis pour 'loyer_mensuel'
    required VoidCallback onSuccess,
  }) async {
    final int amountInSubunits = (montant * 100).toInt();
    final String reference =
        'TRX_${typePaiement.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}';

    // Callback exécuté après un succès de paiement
    Future<void> handleSuccess() async {
      try {
        final batch = _firestore.batch();

        // 1. Préparer les données de la transaction (commun à tous les types)
        final transactionRef = _firestore.collection('transactions').doc();
        final transactionData = {
          'referencePaystack': reference,
          'logementId': logementId,
          'etudiantUid': etudiantUid,
          'bailleurUid': bailleurUid,
          'montant': montant,
          'typePaiement': typePaiement,
          'statut': 'succes',
          'date': FieldValue.serverTimestamp(),
        };

        batch.set(transactionRef, transactionData);

        // 2. Mises à jour spécifiques au type de paiement
        switch (typePaiement) {
          case 'acompte_reservation':
            final logementRef = _firestore
                .collection('logements')
                .doc(logementId);
            batch.update(logementRef, {
              'estReserve': true,
              'statut': 'reserve',
            });

            final demandeQuery = await _firestore
                .collection('demandes_reservation')
                .where('logementId', isEqualTo: logementId)
                .where('etudiantId', isEqualTo: etudiantUid)
                .where('statut', isEqualTo: 'acceptee')
                .limit(1)
                .get();
            if (demandeQuery.docs.isNotEmpty) {
              batch.update(demandeQuery.docs.first.reference, {
                'statut': 'payee',
                'datePaiement': FieldValue.serverTimestamp(),
              });
            }
            break;

          case 'caution':
            if (locationId == null) {
              throw Exception(
                "L'ID de la location est requis pour payer la caution.",
              );
            }
            final locationRef = _firestore
                .collection('locations')
                .doc(locationId);
            batch.update(locationRef, {
              'cautionPayee': true,
              'datePaiementCaution': FieldValue.serverTimestamp(),
            });
            break;

          case 'loyer_mensuel':
            if (locationId == null || echeanceId == null) {
              throw Exception(
                "L'ID de la location et de l'échéance sont requis pour payer le loyer.",
              );
            }
            final echeanceRef = _firestore
                .collection('locations')
                .doc(locationId)
                .collection('echeances')
                .doc(echeanceId);
            batch.update(echeanceRef, {
              'statut': 'paye',
              'datePaiement': FieldValue.serverTimestamp(),
            });
            break;
        }

        // 3. Exécuter l'opération atomique
        await batch.commit();

        // 4. Exécuter le callback de succès fourni
        if (context.mounted) {
          onSuccess();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paiement réussi ! Votre reçu a été généré.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          await PdfService.generateReceipt(transactionData: transactionData);
        }
      } catch (e) {
        debugPrint("Erreur post-paiement Firestore : $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur post-paiement : $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    // Callback si l'utilisateur ferme le popup de paiement
    void handleClosed() {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement annulé.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    try {
      if (kIsWeb) {
        // Redirection vers le script JS d'interopérabilité pour le Web
        _lancerPaiementWeb(
          email: emailEtudiant,
          amountInSubunits: amountInSubunits,
          reference: reference,
          onSuccess: handleSuccess,
          onClose: handleClosed,
        );
      } else {
        // Exécution via le SDK Mobile natif
        await FlutterPaystackPlus.openPaystackPopup(
          publicKey: _publicKey,
          customerEmail: emailEtudiant,
          amount: amountInSubunits.toString(),
          reference: reference,
          currency: 'XOF',
          onClosed: handleClosed,
          onSuccess: handleSuccess,
        );
      }
    } catch (e) {
      debugPrint("Erreur Paystack : $e");
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

  /// Méthode réservée à la plate-forme Web utilisant JavaScript Interop
  static void _lancerPaiementWeb({
    required String email,
    required int amountInSubunits,
    required String reference,
    required VoidCallback onSuccess,
    required VoidCallback onClose,
  }) {
    paystackPopUp(
      _publicKey.toJS,
      email.toJS,
      amountInSubunits.toJS,
      reference.toJS,
      ''.toJS,
      'XOF'.toJS,
      onClose.toJS,
      onSuccess.toJS,
    );
  }
}
