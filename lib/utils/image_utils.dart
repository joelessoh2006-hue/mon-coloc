import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Classe utilitaire pour la manipulation d'images, notamment la compression
/// et l'encodage en Base64.
class ImageUtils {
  /// Redimensionne une image (max 800px sur le côté le plus long), la compresse
  /// en JPEG à 60% de qualité, puis la retourne sous forme de chaîne de caractères
  /// Data URL Base64 (data:image/jpeg;base64,...).
  ///
  /// [inputBytes] : Les octets de l'image à traiter.
  /// Retourne une chaîne Data URL Base64 ou une chaîne vide en cas d'erreur.
  static String compressAndEncodeBase64(Uint8List inputBytes) {
    try {
      // Décoder l'image
      final image = img.decodeImage(inputBytes);
      if (image == null) {
        return ''; // Impossible de décoder l'image
      }

      // Redimensionner l'image si nécessaire (côté le plus long à 800px)
      const int maxSide = 800;
      img.Image resizedImage = image;
      if (image.width > maxSide || image.height > maxSide) {
        resizedImage = img.copyResize(
          image,
          width: image.width > image.height ? maxSide : -1,
          height: image.height > image.width ? maxSide : -1,
        );
      }

      // Compresser l'image en JPEG avec une qualité de 60%
      final compressedBytes = img.encodeJpg(resizedImage, quality: 60);

      // Encoder en Base64 et retourner en tant que Data URL
      return 'data:image/jpeg;base64,${base64Encode(compressedBytes)}';
    } catch (e) {
      // Gérer les erreurs de traitement d'image
      print('Erreur lors de la compression et de l\'encodage Base64 : $e');
      return '';
    }
  }
}
