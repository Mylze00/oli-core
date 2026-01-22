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

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      if (widget.ads.isEmpty) return;

      int nextPage = _currentPage + 1;
      if (nextPage >= widget.ads.length) {
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
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) {
      return Container(
        height: 150,
        color: Colors.grey[900],
        child: const Center(child: Text("Publicité", style: TextStyle(color: Colors.white54))),
      );
    }

    return SizedBox(
      height: 150,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.ads.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final ad = widget.ads[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(ad['image_url'] ?? ''),
                    fit: BoxFit.cover,
                    onError: (e, s) {},
                  ),
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                        ),
                      ),
                    ),
                    if (ad['title'] != null && ad['title'].isNotEmpty)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Text(
                          ad['title'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                          ),
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
                 widget.ads.length,
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
