import 'package:flutter/material.dart';
import '../../../config/api_config.dart';

/// Widget Avatar qui se met à jour automatiquement
/// Résout le problème de l'avatar qui ne s'affiche pas après upload
class AutoRefreshAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double size;
  final IconData fallbackIcon;

  const AutoRefreshAvatar({
    Key? key,
    required this.avatarUrl,
    this.size = 70,
    this.fallbackIcon = Icons.person,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Si pas d'avatar, afficher l'icône par défaut
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          color: Colors.grey[800],
        ),
        child: Icon(fallbackIcon, color: Colors.white, size: size * 0.6),
      );
    }

    // Construire l'URL complète
    String finalUrl = avatarUrl!.startsWith('http') || avatarUrl!.startsWith('data:image')
        ? avatarUrl!
        : '${ApiConfig.baseUrl}/${avatarUrl!.replaceAll(RegExp(r'^/+'), '')}';

    // 🔥 FORCE HTTPS (Correction Mixed Content)
    // Cloudinary et Render sont servis en HTTPS. Si l'URL est http, ça bloque sur PC.
    if (finalUrl.startsWith('http:')) {
      finalUrl = finalUrl.replaceFirst('http:', 'https:');
    }

    // Utiliser Image.network au lieu de DecorationImage pour meilleur contrôle
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: _buildImageWidget(finalUrl),
      ),
    );
  }

  Widget _buildImageWidget(String url) {
    // Si c'est une image base64 (prévisualisation locale)
    if (url.startsWith('data:image')) {
      return Image.network(
        url,
        key: ValueKey(url), // Force rebuild avec nouvelle URL
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(url),
      );
    }

    // Image depuis Cloudinary ou serveur
    return Image.network(
      url,
      key: ValueKey(url), // Force rebuild quand l'URL change
      fit: BoxFit.cover,
      cacheWidth: (size * 2).toInt(), // Optimisation: résolution adaptée
      cacheHeight: (size * 2).toInt(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
            strokeWidth: 2,
            color: Colors.white,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('⚠️ Erreur chargement avatar depuis $url: $error');
        return _buildErrorWidget(url);
      },
    );
  }
  
  Widget _buildErrorWidget(String url) {
    return Container(
      color: Colors.grey[800],
      child: Tooltip(
        message: "Erreur: $url", // Affiche l'URL au survol sur PC
        triggerMode: TooltipTriggerMode.tap, // Au clic sur mobile
        child: Icon(fallbackIcon, color: Colors.redAccent, size: size * 0.6),
      ),
    );
  }
}
