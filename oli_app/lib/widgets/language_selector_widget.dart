import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Widget pour sélectionner la langue de l'application
/// Supporte 6 langues : Français, English, Lingala, Swahili, Kikongo, Tshiluba
class LanguageSelectorWidget extends StatelessWidget {
  const LanguageSelectorWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;

    return GestureDetector(
      onTap: () => _showLanguageDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language,
              size: 18,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              _getLanguageCode(currentLocale),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Obtenir le code de langue à afficher (FR, EN, LN, SW, KG, LU)
  String _getLanguageCode(Locale locale) {
    switch (locale.languageCode) {
      case 'fr':
        return 'FR';
      case 'en':
        return 'EN';
      case 'ln':
        return 'LN';
      case 'sw':
        return 'SW';
      case 'kg':
        return 'KG';
      case 'lu':
        return 'LU';
      default:
        return 'FR';
    }
  }

  /// Afficher le dialogue de sélection de langue
  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('language.select'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(
                context: dialogContext,
                locale: const Locale('fr'),
                flag: '🇫🇷',
                name: 'language.french'.tr(),
              ),
              _buildLanguageOption(
                context: dialogContext,
                locale: const Locale('en'),
                flag: '🇬🇧',
                name: 'language.english'.tr(),
              ),
              _buildLanguageOption(
                context: dialogContext,
                locale: const Locale('ln'),
                flag: '🇨🇩',
                name: 'language.lingala'.tr(),
              ),
              _buildLanguageOption(
                context: dialogContext,
                locale: const Locale('sw'),
                flag: '🇨🇩',
                name: 'language.swahili'.tr(),
              ),
              _buildLanguageOption(
                context: dialogContext,
                locale: const Locale('kg'),
                flag: '🇨🇩',
                name: 'language.kikongo'.tr(),
              ),
              _buildLanguageOption(
                context: dialogContext,
                locale: const Locale('lu'),
                flag: '🇨🇩',
                name: 'language.tshiluba'.tr(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('common.close'.tr()),
            ),
          ],
        );
      },
    );
  }

  /// Construire une option de langue
  Widget _buildLanguageOption({
    required BuildContext context,
    required Locale locale,
    required String flag,
    required String name,
  }) {
    final isSelected = context.locale == locale;

    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(name),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blue)
          : null,
      selected: isSelected,
      onTap: () async {
        await context.setLocale(locale);
        Navigator.of(context).pop();
        
        // Afficher un message de confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'language.select'.tr()}: $name'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}
