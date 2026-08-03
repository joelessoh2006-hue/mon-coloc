import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/screens/chat_screen.dart';
import 'package:mon_coloc/services/visite_service.dart';

class LogementDetailScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> logementData;

  const LogementDetailScreen({
    super.key,
    required this.documentId,
    required this.logementData,
  });

  @override
  State<LogementDetailScreen> createState() => _LogementDetailScreenState();
}

class _LogementDetailScreenState extends State<LogementDetailScreen> {
  String? _idBailleur;

  @override
  void initState() {
    super.initState();
    _idBailleur =
        widget.logementData['idBailleur'] as String? ??
        widget.logementData['bailleurId'] as String? ??
        widget.logementData['userId'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loyer = widget.logementData['loyer'] as int? ?? 0;
    final estReserve = widget.logementData['estReserve'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.logementData['titre'] as String? ?? 'Détails'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.logementData['titre'] as String? ?? '',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${_formaterMontant(loyer)} FCFA / mois',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1E6B4E),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.logementData['description'] as String? ?? '',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomActionButton(
        context,
        theme,
        estReserve,
        loyer.toDouble(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOUTONS D'ACTION EN BAS DE L'ÉCRAN
  // ---------------------------------------------------------------------------
  Widget _bottomActionButton(
    BuildContext context,
    ThemeData theme,
    bool estReserve,
    double loyer,
  ) {
    final acompte = loyer * 0.30;
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. BOUTON : DEMANDER UNE VISITE
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _ouvrirSelecteurDateVisite(context),
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              label: const Text(
                'Demander une visite',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E6B4E),
                side: const BorderSide(color: Color(0xFF1E6B4E)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. BOUTON : RÉSERVER LE LOGEMENT (PAYSTACK)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: estReserve ? null : _envoyerDemandeReservation,
              icon: const Icon(Icons.lock_clock_rounded, size: 20),
              label: Text(
                estReserve
                    ? 'Ce logement est déjà réservé'
                    : 'Réserver (${_formaterMontant(acompte.toInt())} FCFA)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E6B4E),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3. BOUTON : CONTACTER LE BAILLEUR
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                if (_idBailleur == null || _idBailleur!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Information du bailleur manquante.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(destinataireId: _idBailleur!),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              label: const Text(
                'Contacter le bailleur',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E6B4E),
                side: const BorderSide(color: Color(0xFF1E6B4E)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ouvre un sélecteur de date et d'heure pour demander une visite.
  Future<void> _ouvrirSelecteurDateVisite(BuildContext context) async {
    if (_idBailleur == null || _idBailleur!.isEmpty) return;

    final now = DateTime.now();
    final dateChoisie = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      locale: const Locale('fr', 'FR'),
      helpText: 'Choisissez une date de visite',
    );

    if (dateChoisie == null || !mounted) return;

    final heureChoisie = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (heureChoisie == null || !mounted) return;

    final dateVisite = DateTime(
      dateChoisie.year,
      dateChoisie.month,
      dateChoisie.day,
      heureChoisie.hour,
      heureChoisie.minute,
    );

    try {
      final visiteService = VisiteService();
      await visiteService.creerDemandeVisite(
        bailleurId: _idBailleur!,
        logementId: widget.documentId,
        logementTitle: widget.logementData['titre'] as String? ?? 'Logement',
        dateVisite: dateVisite,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de visite envoyée avec succès ! 🎉'),
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

  /// Crée une demande de réservation dans Firestore au lieu de payer directement.
  Future<void> _envoyerDemandeReservation() async {
    final user = FirebaseAuth.instance.currentUser;

    // 1. Vérifier si l'utilisateur est connecté
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez vous connecter pour faire une demande.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 2. Vérifier la présence de l'ID du bailleur
    if (_idBailleur == null || _idBailleur!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Information du bailleur manquante.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      // 3. Récupérer les informations de l'étudiant
      final userDocSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDocSnapshot.exists) {
        throw Exception("Profil utilisateur introuvable.");
      }
      final userDoc = userDocSnapshot.data()!;

      // 4. Ajouter le document dans 'demandes_reservation' avec la nouvelle structure
      final logement = widget.logementData;
      final logementId = widget.documentId;

      await FirebaseFirestore.instance.collection('demandes_reservation').add({
        'etudiantId': user.uid,
        'nomEtudiant': userDoc['nom'] as String? ?? '',
        'prenomEtudiant': userDoc['prenom'] as String? ?? '',
        'telephoneEtudiant': userDoc['telephone'] as String? ?? '',
        'bailleurId': _idBailleur,
        'nomBailleur': logement['nomBailleur'] as String? ?? 'Bailleur',
        'logementId': logementId,
        'titreLogement':
            '${logement['nombrePieces'] ?? 1} pièce(s) - ${logement['quartier'] ?? logement['commune'] ?? 'Abidjan'}',
        'prix': logement['loyer'],
        'dateDemande': FieldValue.serverTimestamp(),
        'statut': 'en_attente',
        // L'ancien champ 'logementInfo' est remplacé par des champs de premier niveau.
      });

      // 5. Afficher un SnackBar de succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Demande envoyée ! Le bailleur doit maintenant l'accepter avant que vous ne puissiez payer.",
            ),
            backgroundColor: Color(0xFF1E6B4E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Gérer les erreurs
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  /// Formate un montant (ex: 150000 -> "150 000")
  String _formaterMontant(int montant) {
    if (montant == 0) return '0';
    final str = montant.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join('');
  }
}
