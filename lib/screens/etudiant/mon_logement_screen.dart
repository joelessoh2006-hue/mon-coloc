import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:mon_coloc/services/user_service.dart';

/// Écran "Mon Logement" pour les étudiants ayant déjà un logement.
/// Permet de uploader des photos, voir/modifier les infos du logement.
class MonLogementScreen extends StatefulWidget {
  const MonLogementScreen({super.key});

  @override
  State<MonLogementScreen> createState() => _MonLogementScreenState();
}

class _MonLogementScreenState extends State<MonLogementScreen> {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  UserModel? _utilisateur;
  bool _chargement = true;
  bool _televersementEnCours = false;
  String? _messageTeleversement;

  // Contrôleurs pour la modification
  final _quartierController = TextEditingController();
  final _loyerTotalController = TextEditingController();
  final _partColocController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _sauvegardeEnCours = false;
  bool _modificationActive = false;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  @override
  void dispose() {
    _quartierController.dispose();
    _loyerTotalController.dispose();
    _partColocController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _chargement = false);
      return;
    }

    // Écouter en temps réel les changements
    _userService.ecouterUtilisateur(uid).listen((user) {
      if (mounted) {
        setState(() {
          _utilisateur = user;
          _chargement = false;
          if (user != null) {
            _initialiserChamps(user);
          }
        });
      }
    });
  }

  void _initialiserChamps(UserModel user) {
    _quartierController.text = user.logementQuartier ?? '';
    _loyerTotalController.text =
        user.logementLoyerTotal?.toStringAsFixed(0) ?? '';
    _partColocController.text =
        user.logementPartColoc?.toStringAsFixed(0) ?? '';
    _descriptionController.text = user.logementDescription ?? '';
  }

  /// Upload d'une photo de logement
  Future<void> _ajouterPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;
      await _televerserPhoto(image);
    } catch (e) {
      _afficherErreur('Erreur lors de la sélection: $e');
    }
  }

  Future<void> _televerserPhoto(XFile image) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _televersementEnCours = true;
      _messageTeleversement = 'Téléversement de la photo…';
    });

    try {
      final currentPhotos = List<String>.from(
        _utilisateur?.logementPhotos ?? [],
      );
      final index = currentPhotos.length;

      String url;
      if (image.path.startsWith('/virtual/') || image.path.isEmpty) {
        final bytes = await image.readAsBytes();
        url = await _userService.televerserPhotoLogementBytes(
          uid: uid,
          bytes: Uint8List.fromList(bytes),
        );
      } else {
        url = await _userService.televerserPhotoLogement(
          uid: uid,
          imageFile: image,
        );
      }

      currentPhotos.add(url);
      await _userService.mettreAJourPartiel(
        uid: uid,
        donnees: {'logementPhotos': currentPhotos},
      );

      if (mounted) {
        setState(() {
          _televersementEnCours = false;
          _messageTeleversement = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo ajoutée avec succès !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur téléversement photo logement: $e');
      if (mounted) {
        setState(() {
          _televersementEnCours = false;
          _messageTeleversement = null;
        });
        _afficherErreur('Erreur: $e');
      }
    }
  }

  /// Supprimer une photo
  Future<void> _supprimerPhoto(int index) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final currentPhotos = List<String>.from(_utilisateur?.logementPhotos ?? []);
    if (index >= currentPhotos.length) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette photo ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    currentPhotos.removeAt(index);
    await _userService.mettreAJourPartiel(
      uid: uid,
      donnees: {'logementPhotos': currentPhotos},
    );
  }

  /// Sauvegarder les modifications des infos logement
  Future<void> _sauvegarderInfos() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _sauvegardeEnCours = true);

    try {
      await _userService.mettreAJourPartiel(
        uid: uid,
        donnees: {
          'logementQuartier': _quartierController.text.trim(),
          'logementLoyerTotal':
              double.tryParse(_loyerTotalController.text.trim()) ?? 0,
          'logementPartColoc':
              double.tryParse(_partColocController.text.trim()) ?? 0,
          'logementDescription': _descriptionController.text.trim(),
        },
      );

      if (mounted) {
        setState(() {
          _sauvegardeEnCours = false;
          _modificationActive = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informations mises à jour !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sauvegardeEnCours = false);
        _afficherErreur('Erreur: $e');
      }
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _utilisateur;
    if (user == null) {
      return const Center(child: Text('Impossible de charger les données.'));
    }

    final hasPhotos = user.logementPhotos.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre
              Text(
                'Mon Logement',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E3A5F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gérez votre annonce et ses photos',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Avertissement si aucune photo
              if (!hasPhotos && !_televersementEnCours)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFFB74D).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFE65100),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Veuillez uploader les photos de votre logement pour activer votre annonce.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!hasPhotos && !_televersementEnCours)
                const SizedBox(height: 24),

              // Overlay de téléversement
              if (_televersementEnCours)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _messageTeleversement ?? 'Traitement…',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              if (_televersementEnCours) const SizedBox(height: 24),

              // --- Section Photos ---
              _buildSection(
                theme: theme,
                icon: Icons.photo_library_rounded,
                title: 'Photos du logement',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasPhotos) ...[
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: user.logementPhotos.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 180,
                                    margin: const EdgeInsets.only(right: 12),
                                    color: Colors.grey.shade200,
                                    child: Builder(
                                      builder: (context) {
                                        final raw = user.logementPhotos[index];
                                        Uint8List? bytes;
                                        try {
                                          if (raw.startsWith('data:image')) {
                                            final base64Part = raw
                                                .split(',')
                                                .last;
                                            bytes = base64Decode(base64Part);
                                          } else {
                                            bytes = base64Decode(raw);
                                          }
                                        } catch (_) {
                                          bytes = null;
                                        }

                                        if (bytes != null) {
                                          return Image.memory(
                                            bytes,
                                            fit: BoxFit.cover,
                                            width: 180,
                                            height: double.infinity,
                                          );
                                        }

                                        return Image.network(
                                          raw,
                                          fit: BoxFit.cover,
                                          width: 180,
                                          height: double.infinity,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: Colors.grey.shade200,
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.broken_image_rounded,
                                                    size: 36,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 20,
                                  child: GestureDetector(
                                    onTap: () => _supprimerPhoto(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _ajouterPhoto,
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        label: Text(
                          hasPhotos
                              ? 'Ajouter une photo'
                              : 'Uploader des photos',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- Section Infos du logement ---
              _buildSection(
                theme: theme,
                icon: Icons.info_rounded,
                title: 'Informations du logement',
                child: Column(
                  children: [
                    // Quartier
                    TextField(
                      controller: _quartierController,
                      enabled: _modificationActive,
                      decoration: InputDecoration(
                        labelText: 'Quartier / Zone',
                        prefixIcon: const Icon(Icons.location_on_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Loyer total
                    TextField(
                      controller: _loyerTotalController,
                      enabled: _modificationActive,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Loyer total (FCFA)',
                        prefixIcon: const Icon(Icons.monetization_on_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Part coloc
                    TextField(
                      controller: _partColocController,
                      enabled: _modificationActive,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Part du colocataire (FCFA)',
                        prefixIcon: const Icon(Icons.money_off_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      enabled: _modificationActive,
                      maxLines: 3,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: const Icon(Icons.description_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Boutons Modifier / Sauvegarder
                    Row(
                      children: [
                        Expanded(
                          child: _modificationActive
                              ? FilledButton.icon(
                                  onPressed: _sauvegardeEnCours
                                      ? null
                                      : _sauvegarderInfos,
                                  icon: _sauvegardeEnCours
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.save_rounded,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _sauvegardeEnCours
                                        ? 'Sauvegarde…'
                                        : 'Enregistrer',
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                )
                              : OutlinedButton.icon(
                                  onPressed: () => setState(
                                    () => _modificationActive = true,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Modifier'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                        ),
                        if (_modificationActive) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _modificationActive = false;
                                  _initialiserChamps(user);
                                });
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Annuler'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}
