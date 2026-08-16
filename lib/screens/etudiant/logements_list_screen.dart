import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'logement_detail_screen.dart';

/// Écran listant les logements disponibles pour les étudiants.
///
/// Récupère tous les logements depuis Firestore (collection "logements")
/// et les affiche sous forme de cartes (Cards) avec des filtres par commune,
/// budget maximum et favoris.
class LogementsListScreen extends StatefulWidget {
  const LogementsListScreen({super.key});

  @override
  State<LogementsListScreen> createState() => _LogementsListScreenState();
}

class _LogementsListScreenState extends State<LogementsListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Filtre : commune sélectionnée (null = toutes)
  String? _communeChoisie;

  /// Filtre : budget maximum saisi (null = aucun filtre)
  final TextEditingController _budgetController = TextEditingController();

  /// Filtre : afficher uniquement les favoris
  bool _filtreFavorisActif = false;

  /// Liste des communes disponibles (copiée depuis add_logement_screen)
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

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  /// Construit la requête Firestore en fonction des filtres sélectionnés.
  Stream<QuerySnapshot> _streamLogements(List<String> favorisIds) {
    // On ne récupère que les logements qui ont été validés par un admin.
    Query query = _firestore
        .collection('logements')
        .where('status', isEqualTo: 'valide');

    // Filtrer par favoris si le filtre est actif et que la liste n'est pas vide
    if (_filtreFavorisActif && favorisIds.isNotEmpty) {
      query = query.where(FieldPath.documentId, whereIn: favorisIds);
    } else if (_filtreFavorisActif && favorisIds.isEmpty) {
      // Si le filtre favoris est actif mais qu'il n'y a aucun favori, on retourne un stream vide.
      return const Stream.empty();
    }

    // Filtrer par commune si une commune est sélectionnée
    if (_communeChoisie != null) {
      query = query.where('commune', isEqualTo: _communeChoisie);
    }

    // NOTE : On retire le orderBy pour éviter un index composite
    // (where + orderBy nécessite un index sur commune+datePublication).
    // Le tri sera fait localement après filtrage.

    return query.snapshots();
  }

  /// Filtre les documents localement (budget, statut de réservation, etc.).
  /// Le filtre `estReserve` est appliqué ici pour éviter un index composite sur Firestore.
  List<DocumentSnapshot> _filtrerLogementsLocalement(
    List<DocumentSnapshot> docs,
  ) {
    // 1. Filtrer les logements non réservés
    List<DocumentSnapshot> filteredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      // Conserver si estReserve est false ou si le champ n'existe pas (null)
      return data?['estReserve'] != true;
    }).toList();

    // 2. Filtrer par budget maximum
    final budgetText = _budgetController.text.trim();
    if (budgetText.isEmpty) return filteredDocs;

    final budgetMax = int.tryParse(budgetText);
    if (budgetMax == null || budgetMax <= 0) return filteredDocs;

    return filteredDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final loyer = data?['loyer'] as int?;
      return loyer != null && loyer <= budgetMax;
    }).toList();
  }

  /// Ajoute ou retire un logement des favoris de l'utilisateur.
  Future<void> _toggleFavori(String logementId, bool estFavori) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDocRef = _firestore.collection('users').doc(user.uid);

    if (estFavori) {
      // Retirer des favoris
      await userDocRef.update({
        'favoris': FieldValue.arrayRemove([logementId]),
      });
    } else {
      // Ajouter aux favoris
      await userDocRef.update({
        'favoris': FieldValue.arrayUnion([logementId]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Veuillez vous connecter.")),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Barre de filtres ----------
            _barreFiltres(theme),

            // ---------- StreamBuilder pour les favoris de l'utilisateur ----------
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore
                    .collection('users')
                    .doc(currentUser.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  final favorisIds =
                      (userSnapshot.data?.data()
                              as Map<String, dynamic>?)?['favoris']
                          as List? ??
                      [];
                  final favoris = favorisIds.cast<String>().toList();

                  // ---------- StreamBuilder pour les logements ----------
                  return StreamBuilder<QuerySnapshot>(
                    stream: _streamLogements(favoris),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Erreur de chargement',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Impossible de récupérer les logements.\nVérifiez votre connexion.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      final docsFiltres = _filtrerLogementsLocalement(docs);

                      if (docsFiltres.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.home_work_rounded,
                                  size: 80,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Aucun logement trouvé',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _filtreFavorisActif
                                      ? 'Vous n\'avez aucun logement en favori correspondant à ces filtres.'
                                      : 'Aucun logement disponible pour ces critères.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: docsFiltres.length,
                        itemBuilder: (context, index) {
                          final doc = docsFiltres[index];
                          final data = doc.data() as Map<String, dynamic>?;

                          if (data == null) return const SizedBox.shrink();

                          final estFavori = favoris.contains(doc.id);

                          return _carteLogement(
                            data: data,
                            theme: theme,
                            documentId: doc.id,
                            estFavori: estFavori,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BARRE DE FILTRES
  // ---------------------------------------------------------------------------
  Widget _barreFiltres(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Dropdown commune
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _communeChoisie,
                  isExpanded: true, // Pour éviter le RenderFlex overflow
                  decoration: InputDecoration(
                    hintText: 'Commune',
                    prefixIcon: const Icon(
                      Icons.location_city_rounded,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.08),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Toutes', style: TextStyle(fontSize: 14)),
                    ),
                    ..._communes.map((commune) {
                      return DropdownMenuItem(
                        value: commune,
                        child: Text(
                          commune,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _communeChoisie = value);
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Champ budget max
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _budgetController,
                  decoration: InputDecoration(
                    hintText: 'Budget max',
                    prefixIcon: const Icon(
                      Icons.monetization_on_rounded,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.08),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Filtre favoris
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Mes favoris'),
              selected: _filtreFavorisActif,
              onSelected: (selected) {
                setState(() {
                  _filtreFavorisActif = selected;
                });
              },
              avatar: Icon(
                _filtreFavorisActif
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 18,
                color: _filtreFavorisActif
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              selectedColor: theme.colorScheme.primary.withOpacity(0.15),
              checkmarkColor: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CARTE LOGEMENT
  // ---------------------------------------------------------------------------
  Widget _carteLogement({
    required Map<String, dynamic> data,
    required ThemeData theme,
    required String documentId,
    required bool estFavori,
  }) {
    // Extraction des champs avec valeurs par défaut
    final commune = data['commune'] as String? ?? 'Non spécifiée';
    final quartier = data['quartier'] as String? ?? '';
    final loyer = data['loyer'] as int? ?? 0;
    final nombrePieces = data['nombrePieces'] as int? ?? 0;
    final cautionMois = data['cautionMois'] as int? ?? 0;
    final piecesLabel = nombrePieces <= 1
        ? '$nombrePieces pièce'
        : '$nombrePieces pièces';

    // Formatage du loyer
    final loyerFormate = _formaterMontant(loyer);

    // Libellé de caution
    final cautionLabel = cautionMois == 1
        ? 'Caution : $cautionMois mois'
        : 'Caution : $cautionMois mois';

    // Localisation
    final localisation = quartier.isNotEmpty ? '$commune, $quartier' : commune;
    final photos = data['logementPhotos'];
    String? imageSource;
    if (photos is List && photos.isNotEmpty) {
      imageSource = photos.firstWhere((p) => p is String && p.isNotEmpty, orElse: () => null) as String?;
    } else if (photos is String && photos.isNotEmpty) {
      imageSource = photos;
    }

    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LogementDetailScreen(
                logementId: documentId,
                logementData: data,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Type + nombre de pièces
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo du logement si disponible
                  if (imageSource != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: _buildPhotoLogement(imageSource),
                      ),
                    )
                  else
                    // Icône par défaut
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        nombrePieces <= 1
                            ? Icons.home_rounded
                            : Icons.apartment_rounded,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  const SizedBox(width: 12),

                  // Texte principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type + pièces
                        Text(
                          'Logement - $piecesLabel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Localisation
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                localisation,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bouton favori
                  IconButton(
                    icon: Icon(
                      estFavori
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: estFavori ? Colors.red.shade400 : Colors.grey,
                    ),
                    onPressed: () => _toggleFavori(documentId, estFavori),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Ligne séparatrice subtile
              Divider(height: 1, color: Colors.grey.withOpacity(0.15)),

              const SizedBox(height: 12),

              // Ligne 2 : Caution et Loyer
              Row(
                children: [
                  Icon(
                    Icons.savings_rounded,
                    size: 16,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cautionLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),

                  // Prix
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E6B4E).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$loyerFormate FCFA/mois',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E6B4E),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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

  /// Nettoie la chaîne Base64 pour retirer l'en-tête Data URL.
  String _nettoyerBase64(String input) {
    if (input.contains(',')) {
      return input.split(',').last;
    }
    return input;
  }

  /// Affiche une photo de logement décodée en Base64 (comme l'admin).
  /// Affiche un placeholder en cas d'erreur de décodage.
  Widget _buildPhotoLogement(String source) {
    // Gère les URL réseau
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholderImage(),
      );
    }
    // Sinon, on suppose que c'est une chaîne Base64 (avec ou sans en-tête)
    try {
      final bytes = base64Decode(_nettoyerBase64(source));
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholderImage(icon: Icons.broken_image_rounded),
      );
    } catch (e) {
      return _placeholderImage(icon: Icons.broken_image_rounded);
    }
  }

  Widget _placeholderImage({IconData icon = Icons.image_not_supported_rounded}) {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        icon,
        color: Colors.grey.shade600,
        size: 32,
      ),
    );
  }
 }