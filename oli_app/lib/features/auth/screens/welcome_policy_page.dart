import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';
import 'profile_setup_page.dart';

class WelcomePolicyPage extends StatelessWidget {
  final String phone;

  const WelcomePolicyPage({super.key, required this.phone});

  static const Color oliBlue = Color(0xFF1E7DBA);

  void _onAccept(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileSetupPage(phone: phone),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    final currentLocale = context.locale.languageCode;

    final languages = [
      {'code': 'fr', 'name': 'Français'},
      {'code': 'en', 'name': 'English'},
      {'code': 'ln', 'name': 'Lingála'},
      {'code': 'sw', 'name': 'Kiswahili'},
      {'code': 'kg', 'name': 'Kikongo'},
      {'code': 'lu', 'name': 'Tshiluba'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF182229)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Choisir la langue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ),
                ...languages.map((lang) {
                  final isSelected = lang['code'] == currentLocale;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? oliBlue : Colors.grey,
                    ),
                    title: Text(
                      lang['name']!,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      context.setLocale(Locale(lang['code']!));
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getLanguageDisplayName(String code) {
    switch (code) {
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      case 'ln':
        return 'Lingála';
      case 'sw':
        return 'Kiswahili';
      case 'kg':
        return 'Kikongo';
      case 'lu':
        return 'Tshiluba';
      default:
        return 'Français';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLang = _getLanguageDisplayName(context.locale.languageCode);

    final bgColor = isDark ? const Color(0xFF0B141A) : const Color(0xFFF7F8FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => _onAccept(context),
            child: Text(
              'Passer',
              style: TextStyle(
                color: subtextColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // 🌟 Illustration circulaire avec logo Oli (Style WhatsApp)
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF101D25) : const Color(0xFFE9F3FA),
                  border: Border.all(
                    color: oliBlue.withValues(alpha: 0.25),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: oliBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Cercles décoratifs
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: oliBlue.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                      ),
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: oliBlue.withValues(alpha: 0.1),
                        ),
                      ),
                      // Logo Oli
                      Hero(
                        tag: 'oli_logo_welcome',
                        child: SvgPicture.asset(
                          'assets/images/logo - Copie (1).svg',
                          width: 110,
                          height: 110,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // 🏷️ Titre de bienvenue
              Text(
                'Bienvenue sur Oli',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 16),

              // 📜 Texte d'information et conditions d'utilisation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: subtextColor,
                    ),
                    children: const [
                      TextSpan(
                        text:
                            'Votre famille, vos ami·es et vos commerçants qui utilisent notre service bénéficient d\'une expérience simple, rapide et sécurisée.\n\nConsultez notre ',
                      ),
                      TextSpan(
                        text: 'Politique de confidentialité',
                        style: TextStyle(
                          color: oliBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '. Appuyez sur « Accepter et continuer » pour accepter les ',
                      ),
                      TextSpan(
                        text: 'Conditions d\'utilisation',
                        style: TextStyle(
                          color: oliBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // 🌐 Sélecteur de langue interactif
              InkWell(
                onTap: () => _showLanguageSelector(context),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF182229) : const Color(0xFFEDF1F5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.language,
                        size: 19,
                        color: oliBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentLang,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: subtextColor,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 🔘 Bouton principal "Accepter et continuer" (Bleu officiel Oli)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _onAccept(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: oliBlue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: oliBlue.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Accepter et continuer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
