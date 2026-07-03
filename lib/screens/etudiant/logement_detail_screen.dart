import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_coloc/screens/chat_screen.dart';
import 'package:mon_coloc/services/user_service.dart';
import 'package:mon_coloc/services/visite_service.dart';
import 'package:mon_coloc/widgets/secure_image_widget.dart';

/// Écran de détail d'un logement.
///
/// Affiche toutes les informations d'un logement sélectionné depuis la liste
/// et propose un bouton pour contacter le bailleur via la messagerie.
/// Le numéro de téléphone du bailleur est masqué ou affiché selon le statut
/// de vérification de l'étudiant connecté.
class LogementDetailScreen extends StatefulWidget {
  /// Données du logement issues du document Firestore.
  final Map<String, dynamic> logementData;

  /// Identifiant du document Firestore.
  final String documentId;

  const LogementDetailScreen({
    super.key,
    required this.logementData,
    required this.documentId,
  });

  @override
  State<LogementDetailScreen> createState() => _LogementDetailScreenState();
}

class _LogementDetailScreenState extends State<LogementDetailScreen> {
  /// Indique si l'étudiant connecté est vérifié (estVerifie == true).
  bool? _estVerifie;

  /// Téléphone du bailleur affiché uniquement si l'étudiant est vérifié.
  String? _bailleurTelephone;

  /// Indique si les données sont en cours de chargement.
  bool _chargement = true;

  /// Identifiant du bailleur depuis les données du logement.
  String? _idBailleur;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _idBailleur = widget.logementData['idBailleur'] as String?;
    _chargerDonnees();
  }

  /// Récupère le statut de vérification de l'étudiant connecté
  /// ainsi que le téléphone du bailleur.
  Future<void> _chargerDonnees() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _estVerifie = false;
          _chargement = false;
        });
        return;
      }

      // Récupérer le document de l'étudiant connecté pour son statut estVerifie
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final estVerifie = userDoc.data()?['estVerifie'] as bool? ?? false;

      // Récupérer le téléphone du bailleur
      String? bailleurTelephone;
      if (_idBailleur != null) {
        final bailleurDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_idBailleur)
            .get();

        if (bailleurDoc.exists) {
          bailleurTelephone = bailleurDoc.data()?['telephone'] as String?;
        }
      }

      if (mounted) {
        setState(() {
          _estVerifie = estVerifie;
          _bailleurTelephone = bailleurTelephone;
          _chargement = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _estVerifie = false;
          _chargement = false;
        });
      }
    }
  }

  /// Masque les 6 derniers chiffres d'un numéro de téléphone.
  /// Ex: "07 09 XX XX XX"
  String _masquerTelephone(String? telephone) {
    if (telephone == null || telephone.isEmpty) return 'XX XX XX XX XX';

    // On enlève les espaces et caractères non numériques pour compter
    final digitsOnly = telephone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 4) return 'XX XX XX XX XX';

    // Garder les 4 premiers chiffres, masquer le reste
    final visible = digitsOnly.substring(0, 4);
    return '${visible.substring(0, 2)} ${visible.substring(2, 4)} XX XX XX';
  }

  Future<void> _ouvrirDialogSignalement() async {
    final motifController = TextEditingController();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Signaler ce logement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Indiquez le motif du signalement :'),
            const SizedBox(height: 12),
            TextField(
              controller: motifController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Motif du signalement',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (motifController.text.trim().isEmpty) {
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirme != true) {
      motifController.dispose();
      return;
    }

    final motif = motifController.text.trim();
    motifController.dispose();

    try {
      await _userService.signalerElement(
        type: 'logement',
        idElement: widget.documentId,
        motif: motif,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signalement envoyé avec succès.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi du signalement : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Extraction des champs avec valeurs par défaut
    final commune =
        widget.logementData['commune'] as String? ?? 'Non spécifiée';
    final quartier = widget.logementData['quartier'] as String? ?? '';
    final loyer = widget.logementData['loyer'] as int? ?? 0;
    final nombrePieces = widget.logementData['nombrePieces'] as int? ?? 0;
    final cautionMois = widget.logementData['cautionMois'] as int? ?? 0;
    final description = widget.logementData['description'] as String? ?? '';

    // Type de logement : "Studio" si <= 1 pièce, sinon "Appartement"
    final typeLogement = nombrePieces <= 1 ? 'Studio' : 'Appartement';
    final piecesLabel = nombrePieces <= 1
        ? '$nombrePieces pièce'
        : '$nombrePieces pièces';

    // Formatage du loyer avec séparateur de milliers
    final loyerFormate = _formaterMontant(loyer);

    // Localisation complète
    final localisation = quartier.isNotEmpty ? '$commune, $quartier' : commune;

    // Libellé caution
    final cautionLabel = cautionMois <= 1
        ? 'Caution : $cautionMois mois'
        : 'Caution : $cautionMois mois';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Contenu défilable ----------
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ----- Bandeau image / placeholder -----
                    _imageBandeau(context, theme),

                    // ----- Corps des informations -----
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Prix mis en valeur
                          Text(
                            '$loyerFormate FCFA',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E6B4E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '/ mois',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ----- Grille de détails -----
                          _detailsGrid(
                            theme: theme,
                            typeLogement: typeLogement,
                            piecesLabel: piecesLabel,
                            commune: commune,
                            quartier: quartier,
                            cautionLabel: cautionLabel,
                          ),

                          const SizedBox(height: 24),

                          // ----- Description -----
                          if (description.isNotEmpty) ...[
                            Text(
                              'Description',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                description,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // ----- Section Contact du Bailleur -----
                          _sectionContactBailleur(theme),

                          const SizedBox(height: 24),

                          // ----- Localisation (carte simulée) -----
                          if (localisation.isNotEmpty) ...[
                            Text(
                              'Localisation',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1E6B4E,
                                ).withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFF1E6B4E,
                                  ).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    color: const Color(0xFF1E6B4E),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      localisation,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E6B4E),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ----- Bouton d'action en bas -----
            _bottomActionButton(context, theme),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION CONTACT DU BAILLEUR
  // ---------------------------------------------------------------------------
  Widget _sectionContactBailleur(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact du Bailleur',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        if (_chargement)
          // Pendant le chargement, afficher un indicateur
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_estVerifie == true)
          // Étudiant vérifié → on affiche le vrai numéro
          _contactVerifie(theme)
        else
          // Étudiant non vérifié → on masque le numéro avec avertissement
          _contactNonVerifie(theme),
      ],
    );
  }

  /// Affichage lorsque l'étudiant est vérifié : vrai numéro + bouton d'appel.
  Widget _contactVerifie(ThemeData theme) {
    final telephone = _bailleurTelephone ?? 'Numéro non disponible';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E6B4E).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1E6B4E).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Icône téléphone
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1E6B4E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.phone_rounded,
              color: Color(0xFF1E6B4E),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Numéro de téléphone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Téléphone',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  telephone,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E6B4E),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // Bouton d'appel simulé
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E6B4E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.phone_rounded, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Appel vers $telephone…',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF1E6B4E),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Affichage lorsque l'étudiant n'est PAS vérifié : numéro masqué + avertissement.
  Widget _contactNonVerifie(ThemeData theme) {
    final telephoneMasque = _masquerTelephone(_bailleurTelephone);

    return Column(
      children: [
        // Bandeau d'avertissement
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pour votre sécurité, le numéro du bailleur est masqué. '
                  'Vous devez faire vérifier votre statut étudiant par '
                  'l\'administration pour débloquer le contact.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade900,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Numéro masqué
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.phone_rounded,
                  color: Colors.red.shade400,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Téléphone (masqué)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      telephoneMasque,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BANDEAU IMAGE (PLACEHOLDER)
  // ---------------------------------------------------------------------------
  Widget _imageBandeau(BuildContext context, ThemeData theme) {
    final photos = widget.logementData['logementPhotos'];
    final imageSource = (photos is List)
        ? (photos as List)
              .firstWhere(
                (value) =>
                    value is String && value.toString().trim().isNotEmpty,
                orElse: () => '',
              )
              .toString()
        : (photos is String ? photos as String : null);

    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: 220,
          child: imageSource != null && imageSource.isNotEmpty
              ? SecureImage(
                  imageSource: imageSource,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  fallbackBackgroundColor: const Color(
                    0xFF1E6B4E,
                  ).withValues(alpha: 0.12),
                  fallbackIconColor: const Color(0xFF1E6B4E),
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E6B4E).withValues(alpha: 0.15),
                        const Color(0xFF1E6B4E).withValues(alpha: 0.05),
                        Colors.grey.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.home_rounded,
                          size: 72,
                          color: const Color(0xFF1E6B4E).withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Photos à venir',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),

        // Bouton retour en haut à gauche
        Positioned(
          top: 12,
          left: 12,
          child: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: const Color(0xFF1E6B4E),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        // Bouton signaler le logement en haut à droite
        Positioned(
          top: 12,
          right: 12,
          child: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            child: IconButton(
              icon: const Icon(Icons.flag_outlined),
              color: const Color(0xFF1E6B4E),
              tooltip: 'Signaler ce logement',
              onPressed: _ouvrirDialogSignalement,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // GRILLE DE DÉTAILS
  // ---------------------------------------------------------------------------
  Widget _detailsGrid({
    required ThemeData theme,
    required String typeLogement,
    required String piecesLabel,
    required String commune,
    required String quartier,
    required String cautionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          // Ligne 1 : Type + Pièces
          _detailRow(
            icon: Icons.home_rounded,
            label: 'Type de bien',
            value: typeLogement,
            theme: theme,
          ),
          const Divider(height: 20),
          _detailRow(
            icon: Icons.meeting_room_rounded,
            label: 'Nombre de pièces',
            value: piecesLabel,
            theme: theme,
          ),
          const Divider(height: 20),
          _detailRow(
            icon: Icons.location_city_rounded,
            label: 'Commune',
            value: commune,
            theme: theme,
          ),
          if (quartier.isNotEmpty) ...[
            const Divider(height: 20),
            _detailRow(
              icon: Icons.map_rounded,
              label: 'Quartier',
              value: quartier,
              theme: theme,
            ),
          ],
          const Divider(height: 20),
          _detailRow(
            icon: Icons.savings_rounded,
            label: 'Caution',
            value: cautionLabel,
            theme: theme,
            iconColor: Colors.amber.shade700,
          ),
        ],
      ),
    );
  }

  /// Une ligne de détail avec icône, label et valeur.
  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor ?? theme.colorScheme.primary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BOUTONS D'ACTION EN BAS
  // ---------------------------------------------------------------------------
  Widget _bottomActionButton(BuildContext context, ThemeData theme) {
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
          // Bouton : Contacter le bailleur
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () {
                if (_idBailleur == null || _idBailleur!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Impossible de contacter le bailleur : information manquante',
                      ),
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
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: const Text(
                'Contacter le bailleur',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E6B4E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Bouton : Demander une visite
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
        ],
      ),
    );
  }

  /// Ouvre un sélecteur de date et d'heure pour demander une visite.
  Future<void> _ouvrirSelecteurDateVisite(BuildContext context) async {
    if (_idBailleur == null || _idBailleur!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de demander une visite : bailleur inconnu'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Sélectionner une date
    final now = DateTime.now();
    final dateChoisie = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      locale: const Locale('fr', 'FR'),
      helpText: 'Choisissez une date de visite',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
    );

    if (dateChoisie == null || !mounted) return;

    // Sélectionner une heure
    final heureChoisie = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Choisissez une heure',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
    );

    if (heureChoisie == null || !mounted) return;

    // Combiner date et heure
    final dateVisite = DateTime(
      dateChoisie.year,
      dateChoisie.month,
      dateChoisie.day,
      heureChoisie.hour,
      heureChoisie.minute,
    );

    // Confirmer avant d'envoyer
    final confirmee = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la visite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vous allez demander une visite pour le logement :'),
            const SizedBox(height: 8),
            Text(
              widget.logementData['titre'] as String? ?? 'Logement',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${dateChoisie.day.toString().padLeft(2, '0')}/'
                  '${dateChoisie.month.toString().padLeft(2, '0')}/'
                  '${dateChoisie.year}',
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${heureChoisie.hour.toString().padLeft(2, '0')}:'
                  '${heureChoisie.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Envoyer la demande'),
          ),
        ],
      ),
    );

    if (confirmee != true || !mounted) return;

    // Envoyer la demande de visite
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
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Demande de visite envoyée avec succès ! 🎉'),
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

  /// Formate un montant avec des séparateurs de milliers (ex: 150000 -> "150 000")
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
