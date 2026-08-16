import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/screens/chat_screen.dart';
import 'package:intl/intl.dart';

class LogementDetailScreen extends StatefulWidget {
  final String logementId;
  final Map<String, dynamic> logementData;

  const LogementDetailScreen({
    super.key,
    required this.logementId,
    required this.logementData,
  });

  @override
  State<LogementDetailScreen> createState() => _LogementDetailScreenState();
}

class _LogementDetailScreenState extends State<LogementDetailScreen> {
  String? _idBailleur;
  Map<String, dynamic>? _bailleurInfos;
  List<String> _photos = [];
  int _photoActuelle = 0;
  final PageController _pageController = PageController();
  bool _reservationEnCours = false;

  @override
  void initState() {
    super.initState();
    // Recherche de l'ID du bailleur dans plusieurs champs possibles
    _idBailleur =
        widget.logementData['idBailleur'] as String? ??
        widget.logementData['bailleurId'] as String? ??
        widget.logementData['userId'] as String?;

    // Extraction des photos
    final photosData = widget.logementData['logementPhotos'];
    if (photosData is List) {
      _photos = photosData
          .whereType<String>()
          .where((p) => p.trim().isNotEmpty)
          .toList();
    } else if (photosData is String && photosData.trim().isNotEmpty) {
      _photos = [photosData];
    }

    _chargerInfosBailleur();
  }

  Future<void> _chargerInfosBailleur() async {
    if (_idBailleur == null || _idBailleur!.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_idBailleur)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _bailleurInfos = doc.data();
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement bailleur: $e");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Nettoie la chaîne Base64 pour retirer l'en-tête Data URL.
  String _nettoyerBase64(String input) {
    if (input.contains(',')) {
      return input.split(',').last;
    }
    return input;
  }

  /// Construit un widget d'image gérant à la fois les URLs réseau (http)
  /// et les chaînes de données Base64 (data:image).
  Widget _buildImage(String source) {
    if (source.startsWith('http')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.broken_image, size: 48);
        },
      );
    }
    // Sinon, on suppose que c'est une chaîne Base64 (avec ou sans en-tête)
    try {
      final bytes = base64Decode(_nettoyerBase64(source));
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 48),
      );
    } catch (e) {
      // Si le décodage échoue, on affiche une icône d'erreur.
      return const Icon(Icons.broken_image, size: 48);
    }
  }

  String _formaterMontant(int montant) {
    return montant.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bailleurNom =
        _bailleurInfos?['prenom'] as String? ?? 'Bailleur vérifié';
    final loyer = widget.logementData['loyer'] as int? ?? 0;
    final estReserve = widget.logementData['estReserve'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.logementData['titre'] as String? ?? 'Détails du logement',
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carrousel d'images
            if (_photos.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    return _buildImage(_photos[index]);
                  },
                  onPageChanged: (index) {
                    setState(() {
                      _photoActuelle = index;
                    });
                  },
                ),
              )
            else
              Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
              ),

            // Information du logement
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.logementData['nombrePieces'] ?? 1} pièce(s) à ${widget.logementData['quartier'] ?? 'Abidjan'}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formaterMontant(loyer)} FCFA / mois',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF1E6B4E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: const Text('Proposé par'),
                    subtitle: Text(
                      bailleurNom,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.logementData['description'] as String? ??
                        'Aucune description fournie.',
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
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

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
          // 1. Demander une visite
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _demanderVisite,
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

          // 2. Réserver le logement
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: estReserve || _reservationEnCours
                  ? null
                  : _reserverLogement,
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

          // 3. Contacter le bailleur
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

  /// Ouvre les sélecteurs de date et d'heure, puis enregistre la demande de visite.
  Future<void> _demanderVisite() async {
    final now = DateTime.now();
    // 1. Ouvrir le sélecteur de date
    final dateChoisie = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)), // Limite à 30 jours
      locale: const Locale('fr', 'FR'),
    );

    if (dateChoisie == null || !mounted) return; // L'utilisateur a annulé

    // 2. Ouvrir le sélecteur d'heure
    final heureChoisie = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );

    if (heureChoisie == null || !mounted) return; // L'utilisateur a annulé

    // 3. Combiner date et heure
    final dateVisite = DateTime(
      dateChoisie.year,
      dateChoisie.month,
      dateChoisie.day,
      heureChoisie.hour,
      heureChoisie.minute,
    );

    // 4. Vérifier l'utilisateur et enregistrer sur Firestore
    final etudiantId = FirebaseAuth.instance.currentUser?.uid;
    if (etudiantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter pour demander une visite.'),
        ),
      );
      return;
    }

    // 1. Récupérer les informations de l'étudiant
    final etudiantDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(etudiantId)
        .get();
    if (!etudiantDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: profil étudiant introuvable.')),
      );
      return;
    }
    final etudiantData = etudiantDoc.data()!;

    // Construction du nom complet avec fallback
    String nomComplet =
        '${etudiantData['prenom'] ?? ''} ${etudiantData['nom'] ?? ''}'.trim();
    if (nomComplet.isEmpty) {
      nomComplet =
          etudiantData['displayName'] as String? ??
          etudiantData['email'] as String? ??
          'Étudiant inconnu';
    }

    try {
      await FirebaseFirestore.instance.collection('visites').add({
        'etudiantId': etudiantId,
        'bailleurId': _idBailleur,
        'logementId': widget.logementId,
        'logementTitle':
            widget.logementData['titre'] as String? ??
            "${widget.logementData['nombrePieces'] ?? ''} pièce(s) à ${widget.logementData['quartier'] ?? ''}",
        'dateVisite': Timestamp.fromDate(dateVisite),
        'etudiantNom': nomComplet, // Clé historique
        'etudiantName': nomComplet, // Alias courant
        'studentName': nomComplet, // Alias courant (utilisé par le modèle)
        'status': 'en_attente', // Consistent with VisiteModel
        'creeLe': FieldValue.serverTimestamp(),
      });

      final dateFormatee = DateFormat(
        'EEEE d MMMM à HH:mm',
        'fr_FR',
      ).format(dateVisite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Votre demande de visite pour le $dateFormatee a été envoyée !',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _reserverLogement() async {
    final etudiantId = FirebaseAuth.instance.currentUser?.uid;
    if (etudiantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter pour réserver.')),
      );
      return;
    }

    if (_idBailleur == null || _idBailleur!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de réserver : information du bailleur manquante.',
          ),
        ),
      );
      return;
    }

    setState(() => _reservationEnCours = true);

    try {
      final demandesRef = FirebaseFirestore.instance.collection(
        'demandes_reservation',
      );

      // Vérifier si une demande existe déjà pour ce logement par cet étudiant
      final demandeExistante = await demandesRef
          .where('etudiantId', isEqualTo: etudiantId)
          .where('logementId', isEqualTo: widget.logementId)
          .limit(1)
          .get();

      if (demandeExistante.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous avez déjà une demande pour ce logement.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 1. Récupérer les informations de l'étudiant
      final etudiantDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(etudiantId)
          .get();
      if (!etudiantDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: profil étudiant introuvable.')),
        );
        return;
      }
      final etudiantData = etudiantDoc.data()!;

      // 2. Construire le nom complet et le téléphone avec une logique robuste
      final prenom = etudiantData['prenom'] as String? ?? '';
      final nom = etudiantData['nom'] as String? ?? '';
      String nomComplet = '$prenom $nom'.trim();

      if (nomComplet.isEmpty) {
        nomComplet = etudiantData['displayName'] as String? ??
            etudiantData['nomComplet'] as String? ??
            etudiantData['name'] as String? ??
            etudiantData['email'] as String? ??
            'Étudiant inconnu';
      }

      final telephone = etudiantData['telephone'] as String? ??
          etudiantData['phone'] as String? ??
          etudiantData['numTelephone'] as String? ??
          etudiantData['num_telephone'] as String? ??
          'Pas de numéro';

      // 3. Récupérer les informations du logement
      final logementTitre = widget.logementData['titre'] as String? ??
          widget.logementData['title'] as String? ??
          "${widget.logementData['nombrePieces'] ?? ''} pièce(s) à ${widget.logementData['quartier'] ?? ''}";
      final loyer = widget.logementData['loyer'] as int? ??
          widget.logementData['prixLoyer'] as int? ??
          widget.logementData['prix'] as int? ??
          0;

      // Créer la demande
      await demandesRef.add({
        // --- Identifiants ---
        'etudiantId': etudiantId,
        'bailleurId': _idBailleur,
        'logementId': widget.logementId,
        // --- Infos Étudiant (avec alias) ---
        'etudiantNom': nomComplet,
        'demandeurNom': nomComplet,
        'studentName': nomComplet,
        'etudiantTelephone': telephone,
        'telephone': telephone,
        'phone': telephone,
        // --- Infos Logement (avec alias) ---
        'logementTitre': logementTitre,
        'logementTitle': logementTitre,
        'titre': logementTitre,
        'loyer': loyer,
        'prixLoyer': loyer,
        'prix': loyer,
        // --- Statut et Date ---
        'statut': 'en_attente',
        'status': 'en_attente', // Alias pour compatibilité
        'creeLe': FieldValue.serverTimestamp(),
        'dateDemande': FieldValue.serverTimestamp(), // Alias pour compatibilité
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Votre demande de réservation a été envoyée au bailleur !',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur réservation: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _reservationEnCours = false);
    }
  }
}
