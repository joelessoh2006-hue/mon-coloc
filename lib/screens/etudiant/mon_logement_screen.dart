import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mon_coloc/models/user_model.dart';
import 'package:mon_coloc/services/user_service.dart';
import 'package:mon_coloc/screens/mon_profil_screen.dart';
import 'package:mon_coloc/screens/etudiant/mes_loyers_screen.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  /// Indique si on affiche le logement du coéquipier.
  bool _afficheLogementCoequipier = false;

  // --- NOUVEAU : Répartition du loyer ---
  /// ID de la conversation de l'équipe
  String? _conversationId;
  /// Nombre de membres dans l'équipe
  int _nombreMembresEquipe = 1;
  /// Mode de répartition ('equitable' ou 'custom')
  bool _repartitionEquitable = true;
  /// Contrôleur pour la part fixe du candidat en mode custom
  final _partFixeCandidatController = TextEditingController();

  /// Prénom du coéquipier si on affiche son logement.
  String? _prenomCoequipier;

  /// UID du coéquipier si on affiche son logement.
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
    _partFixeCandidatController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _chargement = false);
      return;
    }

    final userDoc = await _userService.recupererUtilisateurDoc(uid);
    if (!mounted || userDoc == null) return;

    final currentUser = UserModel.fromFirestore(userDoc);

    // Cas 1 : L'utilisateur a déjà un logement. On affiche ses propres infos.
    if (currentUser.aDejaUnLogement) {
      setState(() {
        _utilisateur = currentUser;
        _afficheLogementCoequipier = false;
        _chargement = false;
        _initialiserChamps(currentUser);
        _chargerInfosEquipe(uid); // Charger aussi les infos de l'équipe
      });
    }
    // Cas 2 : L'utilisateur n'a pas de logement, on cherche celui du coéquipier.
    else {
      final coequipier = await _trouverCoequipierAvecLogement(uid);
      if (coequipier != null) {
        setState(() {
          _utilisateur = coequipier; // On affiche les données du coéquipier
          _prenomCoequipier = coequipier.prenom;
          _afficheLogementCoequipier = true;
          _chargement = false;
          _initialiserChamps(coequipier);
          _chargerInfosEquipe(uid); // Charger aussi les infos de l'équipe
        });
      } else {
        // Aucun coéquipier avec logement trouvé, on affiche l'interface standard.
        setState(() {
          _utilisateur = currentUser;
          _afficheLogementCoequipier = false;
          _chargement = false;
          if (currentUser != null) {
            _initialiserChamps(currentUser);
            _chargerInfosEquipe(uid);
          }
        });
      }
    }
  }

  /// Cherche un coéquipier avec un logement dans une équipe validée.
  Future<UserModel?> _trouverCoequipierAvecLogement(String currentUserUid) async {
    final query = await _firestore
        .collection('conversations')
        .where('membres', arrayContains: currentUserUid)
        .where('demandeStatut', isEqualTo: 'accepte')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final conversation = query.docs.first;
    final membres = List<String>.from(conversation.data()['membres'] ?? []);
    final autreMembreUid = membres.firstWhere((id) => id != currentUserUid, orElse: () => '');

    return await _userService.recupererUtilisateur(autreMembreUid);
  }

  /// Charge les informations de l'équipe (ID conversation, membres, répartition).
  Future<void> _chargerInfosEquipe(String currentUserUid) async {
    final query = await _firestore
        .collection('conversations')
        .where('membres', arrayContains: currentUserUid)
        .where('demandeStatut', isEqualTo: 'accepte')
        .limit(1)
        .get();

    if (query.docs.isEmpty || !mounted) return;

    final doc = query.docs.first;
    final data = doc.data();
    final membres = List<String>.from(data['membres'] ?? []);

    setState(() {
      _conversationId = doc.id;
      _nombreMembresEquipe = membres.length;

      final modeRepartition = data['modeRepartition'] as String?;
      _repartitionEquitable = modeRepartition != 'custom';

      final partFixe = data['partFixeCandidat'] as num?;
      _partFixeCandidatController.text = partFixe?.toStringAsFixed(0) ?? '';
    });

    _partFixeCandidatController.addListener(() => setState(() {}));
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

      final url = await _userService.televerserPhotoLogement(
          uid: uid,
          imageFile: image,
      );

      currentPhotos.add(url); // Ajoute la nouvelle URL à la liste
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
    if (uid == null || _conversationId == null) return;

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

      // --- NOUVEAU : Sauvegarde des infos de répartition dans la conversation ---
      final partFixe = int.tryParse(_partFixeCandidatController.text.trim()) ?? 0;
      final loyerTotal = double.tryParse(_loyerTotalController.text.trim()) ?? 0;
      final partSuggeree = _calculerEtArrondirPartSuggeree(loyerTotal);

      await _firestore.collection('conversations').doc(_conversationId!).update({
        'modeRepartition': _repartitionEquitable ? 'equitable' : 'custom',
        'partFixeCandidat': _repartitionEquitable ? partSuggeree : partFixe,
        'logementQuartier': _quartierController.text.trim(),
      });

      // Recharger les données pour refléter les changements
      await _chargerDonnees();
      // Fin de la nouvelle partie

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

  /// Calcule la part suggérée et l'arrondit au 500 FCFA supérieur.
  int _calculerEtArrondirPartSuggeree(double loyerTotal) {
    if (loyerTotal <= 0) return 0;
    // On calcule la part pour l'équipe actuelle + 1 nouveau membre
    final nbTotalPersonnes = _nombreMembresEquipe + 1;
    final partBrute = loyerTotal / nbTotalPersonnes;
    // Arrondi au 500 FCFA supérieur (ex: 33333 -> 33500)
    return (partBrute / 500).ceil() * 500;
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
                _afficheLogementCoequipier ? 'Notre Logement' : 'Mon Logement',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E3A5F),
                ),
              ),
              const SizedBox(height: 8),
              Text( 
                _afficheLogementCoequipier ? 'Consultez les informations du logement de votre équipe.' : 'Gérez votre annonce et ses photos',
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
              
              // Badge d'information si on affiche le logement du coéquipier
              if (_afficheLogementCoequipier && _prenomCoequipier != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Vous consultez le logement de $_prenomCoequipier.',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                                          errorBuilder: (_, _, _) =>
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
                    if (!_afficheLogementCoequipier)
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

              // --- NOUVEAU : Section Répartition du Loyer ---
              if (user.aDejaUnLogement) ...[
                _buildSectionRepartition(theme),
                const SizedBox(height: 16),
              ],
              if (_afficheLogementCoequipier) ...[
                _buildSectionRepartition(theme),
                const SizedBox(height: 16),
              ],

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
                      enabled: _modificationActive && !_afficheLogementCoequipier,
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
                      enabled: _modificationActive && !_afficheLogementCoequipier,
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
                      enabled: _modificationActive && !_afficheLogementCoequipier,
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
                      enabled: _modificationActive && !_afficheLogementCoequipier,
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

                    // Boutons Modifier / Sauvegarder (uniquement si ce n'est pas le logement du coéquipier)
                    if (!_afficheLogementCoequipier)
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

  /// Construit la section pour la répartition du loyer.
  Widget _buildSectionRepartition(ThemeData theme) {
    final loyerTotal = double.tryParse(_loyerTotalController.text.trim()) ?? 0;
    final partSuggeree = _calculerEtArrondirPartSuggeree(loyerTotal);
    final estEnLectureSeule = _afficheLogementCoequipier;

    return _buildSection(
      theme: theme,
      icon: Icons.payments_rounded,
      title: 'Répartition du Loyer',
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              'Répartition équitable',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Le loyer est divisé par le nombre de colocataires.',
            ),
            value: _repartitionEquitable,
            onChanged: estEnLectureSeule
                ? null
                : (value) {
                    setState(() => _repartitionEquitable = value);
                  },
            activeColor: theme.colorScheme.primary,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          if (_repartitionEquitable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Part suggérée pour le candidat :',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${partSuggeree.toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Part sur-mesure pour le candidat',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _partFixeCandidatController,
                  enabled: !estEnLectureSeule,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montant fixe (FCFA)',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          if (estEnLectureSeule) ...[
            const SizedBox(height: 12),
            Text(
              "Seul le titulaire du logement peut modifier ces réglages.",
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
