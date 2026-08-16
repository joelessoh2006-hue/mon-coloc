import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateReceipt({
    required Map<String, dynamic> transactionData,
  }) async {
    final pdf = pw.Document();

    // 1. Récupération des données basiques
    final reference = transactionData['referencePaystack'] as String? ?? 'N/A';
    final montant = transactionData['montant'] ?? 18000;
    final typePaiement =
        transactionData['typePaiement'] as String? ?? 'acompte_reservation';
    final etudiantUid = transactionData['etudiantUid'] as String?;
    final logementId = transactionData['logementId'] as String?;

    // Date
    DateTime datePaiement = DateTime.now();
    if (transactionData['date'] is Timestamp) {
      datePaiement = (transactionData['date'] as Timestamp).toDate();
    }

    // 2. Récupération des infos complémentaires dans Firestore (Étudiant & Logement)
    Map<String, dynamic>? etudiantData;
    Map<String, dynamic>? logementData;
    Map<String, dynamic>? bailleurData;

    if (etudiantUid != null) {
      final docEtudiant = await FirebaseFirestore.instance
          .collection('users')
          .doc(etudiantUid)
          .get();
      etudiantData = docEtudiant.data();
    }

    if (logementId != null) {
      final docLogement = await FirebaseFirestore.instance
          .collection('logements')
          .doc(logementId)
          .get();
      logementData = docLogement.data();

      // Récupérer les infos du bailleur à partir de l'ID dans le logement
      final idBailleur = logementData?['idBailleur'] as String?;
      if (idBailleur != null) {
        final docBailleur = await FirebaseFirestore.instance
            .collection('users')
            .doc(idBailleur)
            .get();
        bailleurData = docBailleur.data();
      }
    }

    final nomEtudiant =
        '${etudiantData?['prenom'] ?? ''} ${etudiantData?['nom'] ?? ''}'.trim();
    final emailEtudiant = etudiantData?['email'] as String? ?? 'Non fourni';

    // Infos pour le logement et le bailleur
    final nomBailleur =
        '${bailleurData?['prenom'] ?? ''} ${bailleurData?['nom'] ?? ''}'.trim();
    final telephoneBailleur =
        bailleurData?['telephone'] as String? ?? 'Non fourni';
    final nombrePieces = logementData?['nombrePieces'] as int? ?? 1;

    // 3. Construction du PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // Détails Transaction
              _buildSectionTitle(context, 'Détails de la transaction'),
              _buildDetailRow('Référence Paystack:', reference),
              _buildDetailRow(
                'Date du paiement:',
                DateFormat('d MMMM yyyy HH:mm', 'fr_FR').format(datePaiement),
              ),
              _buildDetailRow(
                'Type de paiement:',
                _formatTypePaiement(typePaiement),
              ),
              pw.SizedBox(height: 15),

              // Encart du Montant
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Montant Payé',
                      style: pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '$montant FCFA',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1E6B4E'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Informations Réservation
              _buildSectionTitle(context, 'Informations sur la réservation'),
              _buildDetailRow(
                'Payé par:',
                nomEtudiant.isNotEmpty ? nomEtudiant : 'Étudiant',
              ),
              _buildDetailRow('Email étudiant:', emailEtudiant),
              _buildDetailRow(
                'Logement concerné:',
                'Logement $nombrePieces pièce${nombrePieces > 1 ? 's' : ''} - ${nomBailleur.isNotEmpty ? nomBailleur : 'Bailleur'}',
              ),
              _buildDetailRow('Contact bailleur:', telephoneBailleur),
              pw.SizedBox(height: 30),

              // Pied de page
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Merci d\'utiliser MonColoc. Ce document est un reçu de paiement et ne constitue pas un contrat de bail.',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    // 4. Téléchargement direct du PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'recu_acompte_$reference.pdf',
    );
  }

  // --- Méthodes d'aide UI pour le PDF ---

  static pw.Widget _buildHeader(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'MonColoc',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1E6B4E'),
              ),
            ),
            pw.Text(
              'Votre partenaire logement étudiant',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('#1E6B4E')),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'REÇU DE PAIEMENT',
            style: pw.TextStyle(
              color: PdfColor.fromHex('#1E6B4E'),
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(pw.Context context, String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static String _formatTypePaiement(String type) {
    switch (type) {
      case 'acompte_reservation':
        return 'Acompte de réservation';
      case 'caution':
        return 'Caution / Premier loyer';
      default:
        return type;
    }
  }
}
