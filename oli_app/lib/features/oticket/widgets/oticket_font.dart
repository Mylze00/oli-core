import 'package:flutter/material.dart';

/// Applique à la zone O-Ticket la police de l'écran d'accueil.
class OTicketFont extends StatelessWidget {
  static const String family = 'CreatoDisplay';

  final Widget child;

  const OTicketFont({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: family),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: family),
      ),
      child: DefaultTextStyle(
        style: DefaultTextStyle.of(context).style.copyWith(fontFamily: family),
        child: child,
      ),
    );
  }
}
