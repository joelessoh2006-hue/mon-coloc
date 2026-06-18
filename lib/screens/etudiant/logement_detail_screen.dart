import 'package:flutter/material.dart';

/// Écran de détail d'un logement.
///
/// Affiche toutes les informations d'un logement sélectionné depuis la liste
/// et propose un bouton pour contacter le bailleur via la messagerie.
class LogementDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Extraction des champs avec valeurs par défaut
    final commune = logementData['commune'] as String? ?? 'Non spécifiée';
    final quartier = logementData['quartier'] as String? ?? '';
    final loyer = logementData['loyer'] as int? ?? 0;
    final nombrePieces = logementData['nombrePieces'] as int? ?? 0;
    final cautionMois = logementData['cautionMois'] as int? ?? 0;
    final description = logementData['description'] as String? ?? '';

    // Type de logement : "Studio" si <= 1 pièce, sinon "Appartement"
    final typeLogement = nombrePieces <= 1 ? 'Studio' : 'Appartement';
    final piecesLabel =
        nombrePieces <= 1 ? '$nombrePieces pièce' : '$nombrePieces pièces';

    // Formatage du loyer avec séparateur de milliers
    final loyerFormate = _formaterMontant(loyer);

    // Localisation complète
    final localisation =
        quartier.isNotEmpty ? '$commune, $quartier' : commune;

    // Libellé caution
    final cautionLabel =
        cautionMois <= 1 ? 'Caution : $cautionMois mois' : 'Caution : $cautionMois mois';

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
                                color: const Color(0xFF1E6B4E).withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1E6B4E).withValues(alpha: 0.2),
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
                                      style: theme.textTheme.bodyLarge?.copyWith(
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
  // BANDEAU IMAGE (PLACEHOLDER)
  // ---------------------------------------------------------------------------
  Widget _imageBandeau(BuildContext context, ThemeData theme) {
    return Stack(
      children: [
        // Placeholder large pour les futures images
        Container(
          width: double.infinity,
          height: 220,
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
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.12),
        ),
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
  // BOUTON D'ACTION EN BAS
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
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Connexion à la messagerie en cours…',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Color(0xFF1E6B4E),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
          },
          icon: const Icon(Icons.chat_rounded, size: 22),
          label: const Text(
            'Contacter le bailleur via la messagerie',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E6B4E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
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