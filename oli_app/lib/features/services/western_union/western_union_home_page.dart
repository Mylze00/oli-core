import 'package:oli_app/core/widgets/oli_image.dart';
import 'package:flutter/material.dart';
import 'western_union_send_page.dart';
import 'western_union_receive_page.dart';

class WesternUnionHomePage extends StatefulWidget {
  const WesternUnionHomePage({super.key});

  @override
  State<WesternUnionHomePage> createState() => _WesternUnionHomePageState();
}

class _WesternUnionHomePageState extends State<WesternUnionHomePage> {
  final int _currentCarouselIndex = 0;

  @override
  Widget build(BuildContext context) {
    const wuYellow = Color(0xFFFFDE00);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top Bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                  ),
                  const Text(
                    "WESTERN\nUNION",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: wuYellow,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.2,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),

            // ── Yellow Band Decor ────────────────────────────────
            Container(
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B8000),
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // ── Main Header Title ────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                "Envoyez et recevez\nde l’argent depuis\nle Rép. Dém. du Congo",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: wuYellow,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── White Card Content Section ───────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        "Envoyez de l’argent en ligne à vos proches en quelques instant avec Western Union. Avec plus de 200 pays et territoires couverts, les transferts d’argent internationaux n’ont jamais été aussi simples",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons [ Retrait ] [ Dépôt ]
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const WesternUnionReceivePage(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: wuYellow,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child: const Text(
                                  "Retrait",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const WesternUnionSendPage(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: wuYellow,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child: const Text(
                                  "Dépôt",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Illustration / Banner Carousel
                    Expanded(
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(80),
                              topRight: Radius.circular(80),
                            ),
                            child: Container(
                              width: double.infinity,
                              color: const Color(0xFFF0F2F5),
                              child: OliImage.network(
                                'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=800&q=80',
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Center(
                                  child: Icon(
                                    Icons.public,
                                    size: 100,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Carousel Dots Indicator
                          Positioned(
                            bottom: 14,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(6, (index) {
                                final isActive = index == _currentCarouselIndex;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: isActive ? 10 : 7,
                                  height: isActive ? 10 : 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? const Color(0xFF3B82F6)
                                        : Colors.grey[400],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Accents
                    Container(
                      height: 16,
                      color: Colors.black,
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            color: const Color(0xFF5B46BA),
                          ),
                          const Spacer(),
                          Container(
                            width: 60,
                            decoration: const BoxDecoration(
                              color: wuYellow,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
