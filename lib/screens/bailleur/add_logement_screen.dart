import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

/// Écran de formulaire permettant à un bailleur d'ajouter un nouveau logement.
class AddLogementScreen extends StatefulWidget {
  const AddLogementScreen({super.key});

  @override
  State<AddLogementScreen> createState() => _AddLogementScreenState();
}

class _AddLogementScreenState extends State<AddLogementScreen> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs de saisie
  final _quartierController = TextEditingController();
  final _loyerController = TextEditingController();
  final _piecesController = TextEditingController();
  final _cautionController = TextEditingController();
  final _descriptionController = TextEditingController();

  // État pour la commune sélectionnée
  String? _communeValue;

  // Liste des communes disponibles
  final List<String> _communes = [
    'Cocody',
    'Angré',
    'Yopougon',
    'Marcory',
    'Plateau',
    'Adjamé',
    'Koumassi',
    'Treichville',
    'Port-Bouët',
    'Abobo',
    'Attécoubé',
    'Bingerville',
    'Anyama',
  ];

  // Image picker pour l'ajout réel de photos
  final ImagePicker _picker = ImagePicker();

  // Fichiers sélectionnés localement avant publication
  List<XFile> _selectedPhotos = [];

  // État de chargement pour la publication
  bool _enPublication = false;

  @override
  void dispose() {
    _quartierController.dispose();
    _loyerController.dispose();
    _piecesController.dispose();
    _cautionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Ajoute des photos en ouvrant la galerie et les conserve localement
  /// tant que l'utilisateur n'a pas publié l'annonce.
  Future<void> _ajouterPhotos() async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (images.isEmpty) return;

      if (mounted) {
        setState(() {
          _selectedPhotos = images;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text(
                  'Photos ajoutées. Elles seront téléversées à la publication.',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Erreur lors de la sélection : ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Instead of uploading to Firebase Storage, compress images and return
  /// a list of Base64-encoded JPEG strings to store directly in Firestore.
  Future<List<String>> _televerserPhotos(String uid) async {
    final List<String> b64List = [];

    for (var i = 0; i < _selectedPhotos.length; i++) {
      final XFile file = _selectedPhotos[i];
      print("DEBUG: Compression et encodage Base64 de l'image $i");
      final bytes = await file.readAsBytes();

      try {
        final image = img.decodeImage(bytes);

        if (image != null) {
          // Réduire la résolution si nécessaire (max 1024) puis compresser fortement
          const int maxSide = 1024;
          img.Image resized = image;
          if (image.width > maxSide || image.height > maxSide) {
            if (image.width >= image.height) {
              resized = img.copyResize(image, width: maxSide);
            } else {
              resized = img.copyResize(image, height: maxSide);
            }
          }

          // Qualité faible pour garder la chaîne Base64 légère
          final jpg = img.encodeJpg(resized, quality: 35);
          final b64 = base64Encode(jpg);
          b64List.add(b64);
          print(
            "DEBUG: Image $i compressée (${jpg.length} bytes) et encodée en Base64",
          );
        } else {
          // Si decode échoue, utilser l'original (fallback)
          final b64 = base64Encode(bytes);
          b64List.add(b64);
          print(
            "DEBUG: Image $i non décodable, utilisation du flux original en Base64",
          );
        }
      } catch (e) {
        // En cas d'erreur, sauvegarder l'original en Base64 et continuer
        final b64 = base64Encode(bytes);
        b64List.add(b64);
        print("DEBUG: Erreur lors du traitement image $i : ${e.toString()}");
      }
    }

    return b64List;
  }

  /// Valide et publie le logement dans Firestore
  Future<void> _publierAnnonce() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier que des photos ont été ajoutées
    if (_selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Veuillez ajouter au moins une photo')),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _enPublication = true);
    print("DEBUG: Début de la publication");

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Récupération et parsing sécurisé du loyer
      final loyerText = _loyerController.text.trim();
      final piecesText = _piecesController.text.trim();
      final cautionText = _cautionController.text.trim();

      final loyer = int.tryParse(loyerText) ?? 0;
      final pieces = int.tryParse(piecesText) ?? 0;
      final cautionMois = int.tryParse(cautionText) ?? 0;

      if (loyer <= 0) {
        throw Exception('Le loyer doit être supérieur à 0');
      }
      if (pieces <= 0) {
        throw Exception('Le nombre de pièces doit être supérieur à 0');
      }
      if (cautionMois <= 0) {
        throw Exception('La caution doit être supérieure à 0');
      }

      print(
        "DEBUG: Appel de _televerserPhotos avec ${_selectedPhotos.length} images",
      );
      final logementPhotoUrls = await _televerserPhotos(user.uid);

      print("DEBUG: Tentative d'écriture dans Firestore...");
      // Création du document dans la collection 'logements'
      await FirebaseFirestore.instance.collection('logements').add({
        'idBailleur': user.uid,
        'commune': _communeValue,
        'quartier': _quartierController.text.trim(),
        'loyer': loyer,
        'nombrePieces': pieces,
        'cautionMois': cautionMois,
        'description': _descriptionController.text.trim(),
        'logementPhotos': logementPhotoUrls,
        'datePublication': FieldValue.serverTimestamp(),
        'status': 'en_attente',
        'estReserve': false, // Ajout de la valeur par défaut
      });
      print("DEBUG: Écriture Firestore réussie !");

      if (!mounted) return;

      // SnackBar de succès
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Annonce enregistrée, en attente de validation par l\'administrateur',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF1E6B4E),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );

      // Retour à l'écran d'accueil du bailleur
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() => _enPublication = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Firebase erreur : ${e.message ?? e.code}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _enPublication = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Erreur : ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _enPublication = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Publier un logement',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------- Titre de la section ----------
                Text(
                  'Informations du logement',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Remplissez tous les champs obligatoires ci-dessous.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // ---------- Commune (Dropdown) ----------
                _sectionLabel('Commune *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _communeValue,
                  decoration: _inputDecoration(
                    hint: 'Sélectionnez une commune',
                    prefixIcon: Icons.location_city_rounded,
                  ),
                  items: _communes.map((commune) {
                    return DropdownMenuItem(
                      value: commune,
                      child: Text(commune),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _communeValue = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez sélectionner une commune';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ---------- Quartier ----------
                _sectionLabel('Quartier précis *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _quartierController,
                  decoration: _inputDecoration(
                    hint: 'Ex: Riviera 3, 2 Plateaux',
                    prefixIcon: Icons.map_rounded,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez préciser le quartier';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ---------- Loyer mensuel ----------
                _sectionLabel('Loyer mensuel (FCFA) *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _loyerController,
                  decoration: _inputDecoration(
                    hint: 'Ex: 150000',
                    prefixIcon: Icons.monetization_on_rounded,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez indiquer le loyer';
                    }
                    final montant = int.tryParse(value.trim());
                    if (montant == null || montant <= 0) {
                      return 'Montant invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ---------- Nombre de pièces ----------
                _sectionLabel('Nombre de pièces *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _piecesController,
                  decoration: _inputDecoration(
                    hint: 'Ex: 3',
                    prefixIcon: Icons.meeting_room_rounded,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez indiquer le nombre de pièces';
                    }
                    final nb = int.tryParse(value.trim());
                    if (nb == null || nb <= 0) {
                      return 'Nombre invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ---------- Caution / Avance ----------
                _sectionLabel('Caution / Avance (nombre de mois) *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _cautionController,
                  decoration: _inputDecoration(
                    hint: 'Ex: 2',
                    prefixIcon: Icons.savings_rounded,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez indiquer la caution';
                    }
                    final nb = int.tryParse(value.trim());
                    if (nb == null || nb <= 0) {
                      return 'Nombre de mois invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ---------- Description ----------
                _sectionLabel('Description du bien *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _inputDecoration(
                    hint: 'Décrivez le logement, les commodités, etc.',
                    prefixIcon: Icons.description_rounded,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez décrire le logement';
                    }
                    if (value.trim().length < 10) {
                      return 'La description doit contenir au moins 10 caractères';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ---------- Photos (Simulation) ----------
                Text(
                  'Photos du logement *',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _ajouterPhotos,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedPhotos.isNotEmpty
                          ? const Color(0xFF1E6B4E).withOpacity(0.08)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedPhotos.isNotEmpty
                            ? const Color(0xFF1E6B4E)
                            : Colors.grey.withOpacity(0.3),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedPhotos.isNotEmpty
                              ? Icons.check_circle
                              : Icons.add_a_photo,
                          size: 28,
                          color: _selectedPhotos.isNotEmpty
                              ? const Color(0xFF1E6B4E)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedPhotos.isNotEmpty
                              ? 'Photos ajoutées ✓'
                              : 'Ajouter des photos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedPhotos.isNotEmpty
                                ? const Color(0xFF1E6B4E)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedPhotos.isNotEmpty) _buildPhotoPreview(),
                const SizedBox(height: 32),

                // ---------- Bouton de publication ----------
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _enPublication ? null : _publierAnnonce,
                    icon: _enPublication
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.publish_rounded, size: 22),
                    label: Text(
                      _enPublication
                          ? 'Publication en cours…'
                          : 'Publier l\'annonce',
                      style: const TextStyle(
                        fontSize: 16,
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
                const SizedBox(height: 16),

                // Mention obligatoire
                Text(
                  '* Champs obligatoires',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Petit label de section
  Widget _sectionLabel(String texte) {
    return Text(
      texte,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  /// Widget d'aperçu des photos sélectionnées
  Widget _buildPhotoPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Aperçu des photos',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            _selectedPhotos.length,
            (index) => _buildPhotoChip(index),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoChip(int index) {
    final file = _selectedPhotos[index];

    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  width: 96,
                  height: 96,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return Container(
                  width: 96,
                  height: 96,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              }

              return Image.memory(
                snapshot.data!,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _selectedPhotos.removeAt(index);
                });
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Décoration réutilisable pour les champs de saisie
  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, size: 22),
      alignLabelWithHint: alignLabelWithHint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey.withOpacity(0.08),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: const Color(0xFF1E6B4E), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }
}
