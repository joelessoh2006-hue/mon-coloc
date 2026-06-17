// Écran de sélection du rôle
// Point de départ avant d'entrer dans les formulaires d'inscription
// Redirige vers le parcours Étudiant (3 étapes) ou Bailleur (formulaire dédié + documents)

import 'package:flutter/material.dart';
import 'package:mon_coloc/screens/auth/register_page.dart';
import 'package:mon_coloc/screens/auth/register_bailleur_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  final VoidCallback onInscriptionTerminee;

  const RoleSelectionScreen({super.key, required this.onInscriptionTerminee});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bouton retour
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Icône
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Titre
              Center(
                child: Text(
                  'Créer un compte',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Choisissez votre profil pour continuer',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Carte Étudiant
              _carteRole(
                theme: theme,
                icone: Icons.school_rounded,
                titre: 'Je suis un Étudiant',
                description:
                    'Je cherche un logement ou un colocataire près de mon école',
                couleur: const Color(0xFF7C3AED),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RegisterPage(
                        role: 'etudiant',
                        onInscriptionTerminee: onInscriptionTerminee,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Carte Bailleur
              _carteRole(
                theme: theme,
                icone: Icons.home_work_rounded,
                titre: 'Je suis un Bailleur',
                description:
                    'Je propose un logement aux étudiants et deviens propriétaire',
                couleur: const Color(0xFF059669),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RegisterBailleurScreen(
                        onInscriptionTerminee: onInscriptionTerminee,
                      ),
                    ),
                  );
                },
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteRole({
    required ThemeData theme,
    required IconData icone,
    required String titre,
    required String description,
    required Color couleur,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: couleur.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icone,
                size: 32,
                color: couleur,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: couleur.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: couleur,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}