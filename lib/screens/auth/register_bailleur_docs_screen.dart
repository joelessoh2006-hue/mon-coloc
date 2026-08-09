// Écran de téléversement de documents pour le parcours Bailleur
// Documents requis : Pièce d'identité, Justificatif de propriété, Justificatif de domicile

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Représente un fichier sélectionné via FilePicker
class FichierDocument {
  final String nom;
  final Uint8List bytes;
  final String? chemin;

  FichierDocument({
    required this.nom,
    required this.bytes,
    this.chemin,
  });
}

/// État de téléversement d'un document
enum DocumentUploadState {
  nonSelectionne,
  selectionne,
}

class RegisterBailleurDocsScreen extends StatefulWidget {
  final VoidCallback onFinaliser;
  final VoidCallback onRetour;
  final void Function(List<FichierDocument?> fichiers) onFichiersChanges;

  const RegisterBailleurDocsScreen({
    super.key,
    required this.onFinaliser,
    required this.onRetour,
    required this.onFichiersChanges,
  });

  @override
  State<RegisterBailleurDocsScreen> createState() =>
      _RegisterBailleurDocsScreenState();
}

class _RegisterBailleurDocsScreenState
    extends State<RegisterBailleurDocsScreen> {
  // État de chaque document
  DocumentUploadState _pieceIdentite = DocumentUploadState.nonSelectionne;
  DocumentUploadState _justificatifPropriete =
      DocumentUploadState.nonSelectionne;
  DocumentUploadState _justificatifDomicile =
      DocumentUploadState.nonSelectionne;

  // Fichiers sélectionnés (nom + bytes pour compatibilité Web)
  String? _nomPieceIdentite;
  String? _nomJustificatifPropriete;
  String? _nomJustificatifDomicile;

  FichierDocument? _fichierPieceIdentite;
  FichierDocument? _fichierJustificatifPropriete;
  FichierDocument? _fichierJustificatifDomicile;

  Future<void> _pickerFichier(int index) async {
    try {
      // Remplace FilePicker.platform.pickFiles par :
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
  withData: true,
);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        final nom = file.name;

        if (bytes == null) {
          _afficherErreur("Impossible de lire le fichier sélectionné.");
          return;
        }

        // Vérification de la taille du fichier (500 Ko)
        const maxSizeInBytes = 500 * 1024;
        if (bytes.lengthInBytes > maxSizeInBytes) {
          _afficherErreur(
            "Le fichier '$nom' est trop lourd (max 500 Ko). Veuillez choisir un fichier plus léger ou le compresser.",
          );
          return;
        }

        setState(() {
          switch (index) {
            case 0:
              _pieceIdentite = DocumentUploadState.selectionne;
              _nomPieceIdentite = nom;
              _fichierPieceIdentite = FichierDocument(
                nom: nom,
                bytes: bytes,
                chemin: file.path,
              );
              break;
            case 1:
              _justificatifPropriete = DocumentUploadState.selectionne;
              _nomJustificatifPropriete = nom;
              _fichierJustificatifPropriete = FichierDocument(
                nom: nom,
                bytes: bytes,
                chemin: file.path,
              );
              break;
            case 2:
              _justificatifDomicile = DocumentUploadState.selectionne;
              _nomJustificatifDomicile = nom;
              _fichierJustificatifDomicile = FichierDocument(
                nom: nom,
                bytes: bytes,
                chemin: file.path,
              );
              break;
          }
        });

        // Notifier le parent des changements
        widget.onFichiersChanges([
          _fichierPieceIdentite,
          _fichierJustificatifPropriete,
          _fichierJustificatifDomicile,
        ]);
      }
    } catch (e) {
      _afficherErreur("Erreur lors de la sélection du fichier : $e");
    }
  }

  void _soumettre() {
    if (_pieceIdentite != DocumentUploadState.selectionne) {
      _afficherErreur('Veuillez téléverser votre pièce d\'identité.');
      return;
    }
    if (_justificatifPropriete != DocumentUploadState.selectionne) {
      _afficherErreur('Veuillez téléverser votre justificatif de propriété.');
      return;
    }
    if (_justificatifDomicile != DocumentUploadState.selectionne) {
      _afficherErreur('Veuillez téléverser votre justificatif de domicile.');
      return;
    }

    widget.onFinaliser();
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tousDocumentsOk =
        _pieceIdentite == DocumentUploadState.selectionne &&
            _justificatifPropriete == DocumentUploadState.selectionne &&
            _justificatifDomicile == DocumentUploadState.selectionne;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _construireEnTete(theme),
                    const SizedBox(height: 12),

                    // Message d'information
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        border: Border.all(
                          color: const Color(0xFFBFDBFE),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              size: 24,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Documents requis',
                                  style:
                                      theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E40AF),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Pour devenir bailleur, veuillez fournir '
                                  'les documents ci-dessous. Ils seront vérifiés '
                                  'par notre équipe avant activation de votre compte.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF3B82F6),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ---- Pièce d'identité ----
                    _carteDocument(
                      theme: theme,
                      index: 0,
                      icone: Icons.badge_rounded,
                      titre: "Pièce d'identité",
                      description:
                          'CNI, Passeport ou Carte de séjour en cours de validité',
                      statut: _pieceIdentite,
                      nomFichier: _nomPieceIdentite,
                    ),
                    const SizedBox(height: 14),

                    // ---- Justificatif de propriété ----
                    _carteDocument(
                      theme: theme,
                      index: 1,
                      icone: Icons.description_rounded,
                      titre: 'Justificatif de propriété',
                      description:
                          'Titre de propriété, ACD ou Contrat de bail',
                      statut: _justificatifPropriete,
                      nomFichier: _nomJustificatifPropriete,
                    ),
                    const SizedBox(height: 14),

                    // ---- Justificatif de domicile ----
                    _carteDocument(
                      theme: theme,
                      index: 2,
                      icone: Icons.home_rounded,
                      titre: 'Justificatif de domicile',
                      description:
                          'Facture CIE ou SODECI à votre nom (moins de 3 mois)',
                      statut: _justificatifDomicile,
                      nomFichier: _nomJustificatifDomicile,
                    ),
                    const SizedBox(height: 32),

                    // Résumé
                    if (tousDocumentsOk)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          border: Border.all(
                            color: const Color(0xFFBBF7D0),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF16A34A),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tous les documents sont sélectionnés. '
                                'Vous pouvez finaliser votre inscription.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Navigation
            _construireNavigation(theme),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // En-tête
  // ---------------------------------------------------------------------------
  Widget _construireEnTete(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.verified_rounded,
            color: Color(0xFF059669),
            size: 26,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Documents bailleur',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Fournissez vos documents pour devenir bailleur',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Validation bailleur',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF059669),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Carte document avec bouton de téléversement
  // ---------------------------------------------------------------------------
  Widget _carteDocument({
    required ThemeData theme,
    required int index,
    required IconData icone,
    required String titre,
    required String description,
    required DocumentUploadState statut,
    String? nomFichier,
  }) {
    final bool estSelectionne = statut == DocumentUploadState.selectionne;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: estSelectionne
            ? const Color(0xFFF0FDF4)
            : Colors.white,
        border: Border.all(
          color: estSelectionne
              ? const Color(0xFF86EFAC)
              : const Color(0xFFE5E7EB),
          width: estSelectionne ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: estSelectionne
                ? const Color(0xFF16A34A).withOpacity(0.08)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône + Titre
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: estSelectionne
                      ? const Color(0xFF16A34A).withOpacity(0.12)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icone,
                  size: 24,
                  color: estSelectionne
                      ? const Color(0xFF16A34A)
                      : theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: estSelectionne
                            ? const Color(0xFF15803D)
                            : const Color(0xFF1E3A5F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nom du fichier sélectionné (visible après sélection)
          if (estSelectionne && nomFichier != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.insert_drive_file_rounded,
                    size: 18,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nomFichier,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _pickerFichier(index),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Bouton de téléversement
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pickerFichier(index),
              icon: Icon(
                estSelectionne
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                size: 20,
                color: estSelectionne
                    ? const Color(0xFF16A34A)
                    : theme.colorScheme.primary,
              ),
              label: Text(
                estSelectionne
                    ? 'Changer le fichier'
                    : 'Téléverser le document',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: estSelectionne
                      ? const Color(0xFF16A34A)
                      : theme.colorScheme.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: estSelectionne
                      ? const Color(0xFF86EFAC)
                      : theme.colorScheme.outline,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: estSelectionne
                    ? const Color(0xFF16A34A).withOpacity(0.05)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Barre de navigation
  // ---------------------------------------------------------------------------
  Widget _construireNavigation(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: widget.onRetour,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Retour'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              side: BorderSide(color: theme.colorScheme.outline),
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _soumettre,
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text(
                  "Terminer l'inscription",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}