import 'package:flutter/material.dart';
import 'package:mon_coloc/services/signalement_service.dart';

/// Affiche une boîte de dialogue modale pour permettre à l'utilisateur de signaler un contenu.
///
/// [context]: Le BuildContext de l'écran appelant.
/// [cibleId]: L'ID de l'élément signalé (logement, utilisateur, etc.).
/// [typeCible]: Le type de l'élément signalé ('logement', 'utilisateur', etc.).
void afficherDialogueSignalement(
  BuildContext context, {
  required String cibleId,
  required String typeCible,
}) {
  // La liste des motifs est maintenant dynamique selon le type de cible.
  final List<String> motifs;
  if (typeCible.contains('profil') || typeCible.contains('etudiant')) {
    // Motifs pour signaler un utilisateur (profil, étudiant, etc.)
    motifs = [
      'Harcèlement',
      'Langage offensant',
      'Information trompeuse',
      'Escroquerie',
      'Contenu inapproprié',
      'Autre',
    ];
  } else {
    // Motifs par défaut ou pour un logement
    motifs = [
      'Arnaque',
      'Contenu inapproprié',
      'Logement déjà loué',
      'Informations incorrectes',
      'Autre',
    ];
  }
  String motifSelectionne = motifs.first;
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Signaler un problème'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quel est le motif de votre signalement ?',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: motifSelectionne,
                    isExpanded: true,
                    items: motifs.map((motif) {
                      return DropdownMenuItem(value: motif, child: Text(motif));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          motifSelectionne = value;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () async {
                  final parentContext = context;
                  Navigator.pop(dialogContext); // Ferme la boîte de dialogue
                  await _traiterSignalement(
                    parentContext,
                    cibleId,
                    typeCible,
                    motifSelectionne,
                  );
                },
                child: const Text('Signaler'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Appelle le service pour envoyer le signalement et affiche un SnackBar.
Future<void> _traiterSignalement(
  BuildContext context,
  String cibleId,
  String typeCible,
  String motif,
) async {
  // On capture le ScaffoldMessenger avant l'opération asynchrone.
  // Cela garantit que nous avons une référence valide pour afficher le SnackBar,
  // même si le contexte d'origine n'est plus dans l'arbre des widgets.
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  try {
    final signalementService = SignalementService();
    await signalementService.envoyerSignalement(
      cibleId: cibleId,
      typeCible: typeCible,
      motif: motif,
    );
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text(
          'Signalement accepté. Votre demande sera traitée par un administrateur.',
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Erreur lors de l\'envoi du signalement : $e'),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
