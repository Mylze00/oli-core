import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdsCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> ads;

  const AdsCarousel({super.key, required this.ads});

  @override
  State<AdsCarousel> createState() => _AdsCarouselState();
}

class _AdsCarouselState extends State<AdsCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAdImages();
  }

  @override
  void didUpdateWidget(covariant AdsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ads != widget.ads) {
      _precacheAdImages();
    }
  }

  /// Précharge en mémoire les images pour éviter tout clignotement ou re-téléchargement
  void _precacheAdImages() {
    for (final ad in _effectiveAds) {
      final rawUrl = ad['image_url']?.toString();
      if (rawUrl != null && rawUrl.trim().isNotEmpty) {
        final optimized = getOptimizedAdUrl(rawUrl);
        precacheImage(NetworkImage(optimized), context);
      } else if (ad['asset'] != null) {
        precacheImage(AssetImage(ad['asset']), context);
      }
    }
  }

  /// Optimise l'URL Cloudinary : compression 50% (q_50), format automatique (f_auto) et largeur retina (w_800)
  static String getOptimizedAdUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();
    if (trimmed.contains('cloudinary.com') && trimmed.contains('/upload/')) {
      if (!trimmed.contains('/upload/q_')) {
        return trimmed.replaceFirst('/upload/', '/upload/q_50,f_auto,w_800/');
      }
    }
    return trimmed;
  }

  List<Map<String, dynamic>> get _effectiveAds {
    if (widget.ads.isNotEmpty) return widget.ads;
    return [
      {'image_url': 'https://i.ibb.co/8LpR9qhh/57321680-650635498739924-7874656008449032192-n.jpg', 'title': 'Publicité'},
      {'image_url': 'https://i.ibb.co/yBqF4BjX/486150569-1082236427267170-6353656641332678854-n.jpg', 'title': 'Publicité'},
      {'image_url': 'https://i.ibb.co/QvqSTNJ9/Fally-Ipupa-Sd-F-879x555-Fiche-e-ve-nement-concert-supp-jpg.webp', 'title': 'Concert Fally Ipupa'},
      {'image_url': 'https://i.ibb.co/svk6yQzZ/Screenshot-2-thumbnail.jpg', 'title': 'Kin Marché'},
    ];
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted) return;
      if (_effectiveAds.isEmpty) return;

      int nextPage = _currentPage + 1;
      if (nextPage >= _effectiveAds.length) {
        nextPage = 0;
      }

      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      
      setState(() {
        _currentPage = nextPage;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildAdImage(Map<String, dynamic> ad, {required BoxFit fit, int? cacheWidth}) {
    if (ad['asset'] != null) {
      return Image.asset(
        ad['asset'],
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth ?? 800,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.image_not_supported, color: Colors.white24),
        ),
      );
    }

    final rawUrl = ad['image_url']?.toString() ?? '';
    final optimizedUrl = getOptimizedAdUrl(rawUrl);

    return Image.network(
      optimizedUrl,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheWidth ?? 800, // Limite et allège la consommation mémoire RAM
      errorBuilder: (ctx, err, stack) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: Colors.white24, size: 30),
              SizedBox(height: 4),
              Text(
                "Image indisponible",
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final adsList = _effectiveAds;

    if (adsList.isEmpty) {
      return Container(
        height: 195,
        color: Colors.grey[900],
        child: const Center(child: Text("Publicité", style: TextStyle(color: Colors.white54))),
      );
    }

    return SizedBox(
      height: 195,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: adsList.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final ad = adsList[index];
              return GestureDetector(
                onTap: () async {
                  final rawUrl = ad['link_url'] ?? ad['destination_url'] ?? ad['link'];
                  if (rawUrl != null && rawUrl.toString().trim().isNotEmpty) {
                    final uri = Uri.tryParse(rawUrl.toString().trim());
                    if (uri != null) {
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        debugPrint("Erreur ouverture URL pub: $e");
                      }
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[950],
                  ),
                  clipBehavior: Clip.antiAlias,
                  // Ajuste l'image directement sur toute la zone sans marges ni débordement
                  child: _buildAdImage(ad, fit: BoxFit.fill, cacheWidth: 800),
                ),
              );
            },
          ),
          // Indicateurs avec fond contrasté
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  adsList.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: _currentPage == index ? 12 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.blue
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
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
