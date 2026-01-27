import 'dart:async';
import 'package:flutter/material.dart';

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

  @override
  @override
  Widget build(BuildContext context) {
    final adsList = _effectiveAds;

    if (adsList.isEmpty) {
      return Container(
        height: 172, // +15%
        color: Colors.grey[900],
        child: const Center(child: Text("Publicité", style: TextStyle(color: Colors.white54))),
      );
    }

    return SizedBox(
      height: 172, // +15%
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
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[900], // Fallback background
                ),
                clipBehavior: Clip.antiAlias, // Ensure child respects border radius
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ad['asset'] != null
                          ? Image.asset(
                              ad['asset'],
                              fit: BoxFit.fill,
                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported, color: Colors.white24)),
                            )
                          : Image.network(
                              ad['image_url'] ?? '',
                              fit: BoxFit.fill,
                              errorBuilder: (ctx, err, stack) {
                                return const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, color: Colors.white24, size: 30),
                                      SizedBox(height: 4),
                                      Text("Image indisponible", style: TextStyle(color: Colors.white24, fontSize: 10)),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Indicateurs
          Positioned(
             bottom: 8,
             right: 8,
             child: Row(
               children: List.generate(
                 adsList.length,
                 (index) => Container(
                   margin: const EdgeInsets.symmetric(horizontal: 2),
                   width: _currentPage == index ? 12 : 6,
                   height: 6,
                   decoration: BoxDecoration(
                     color: _currentPage == index ? Colors.blue : Colors.white.withOpacity(0.5),
                     borderRadius: BorderRadius.circular(3),
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
