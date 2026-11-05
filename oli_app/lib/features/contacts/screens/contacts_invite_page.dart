import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/router/network/dio_provider.dart';
import '../../auth/providers/auth_controller.dart';
import '../services/contacts_match_service.dart';
import '../utils/phone_normalizer.dart';

/// Un contact du carnet, avec son numéro normalisé.
class _ContactEntry {
  final String phone;
  final String displayName;
  const _ContactEntry({required this.phone, required this.displayName});
}

/// « Trouver mes contacts » : affiche les contacts déjà sur Oli et permet d'inviter les autres
/// par lien. Les contacts non inscrits ne quittent jamais le téléphone.
class ContactsInvitePage extends ConsumerStatefulWidget {
  const ContactsInvitePage({super.key});

  @override
  ConsumerState<ContactsInvitePage> createState() => _ContactsInvitePageState();
}

class _ContactsInvitePageState extends ConsumerState<ContactsInvitePage> {
  static const String _inviteBaseUrl = 'https://oli-core.web.app/';

  bool _loading = false;
  bool _permissionDenied = false;
  String? _error;
  List<_ContactEntry> _onOli = [];
  List<_ContactEntry> _notOnOli = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trouver mes contacts'),
        content: const Text(
          'Oli va lire les numéros de votre carnet d\'adresses pour vous montrer les contacts déjà inscrits. '
          'Les numéros sont envoyés de façon sécurisée et ne sont pas conservés. '
          'Les contacts non inscrits restent uniquement sur votre téléphone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuer')),
        ],
      ),
    );

    if (consent != true) {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });

    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);

      // Un seul contact par numéro normalisé
      final byPhone = <String, _ContactEntry>{};
      for (final c in contacts) {
        for (final p in c.phones) {
          final normalized = normalizePhone(p.number);
          if (normalized != null && !byPhone.containsKey(normalized)) {
            byPhone[normalized] = _ContactEntry(phone: normalized, displayName: c.displayName);
          }
        }
      }

      final service = ContactsMatchService(ref.read(dioProvider));
      final matches = await service.matchPhones(byPhone.keys.toList());
      final matchedPhones = matches.map((m) => m.phone).toSet();

      final onOli = byPhone.values.where((e) => matchedPhones.contains(e.phone)).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      final notOnOli = byPhone.values.where((e) => !matchedPhones.contains(e.phone)).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

      if (mounted) {
        setState(() {
          _onOli = onOli;
          _notOnOli = notOnOli;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible de synchroniser vos contacts. Réessayez plus tard.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _invite() {
    final idOli = ref.read(authControllerProvider).userData?['id_oli']?.toString() ?? '';
    final link = idOli.isEmpty ? _inviteBaseUrl : '$_inviteBaseUrl?ref=$idOli';
    Share.share('Rejoins-moi sur Oli, la marketplace de la RDC ! $link');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trouver mes contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Inviter par lien',
            onPressed: _invite,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_permissionDenied) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'L\'accès à vos contacts est refusé. Vous pouvez l\'autoriser dans les réglages de votre téléphone.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _start, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        _sectionTitle('Déjà sur Oli (${_onOli.length})'),
        if (_onOli.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Aucun de vos contacts n\'est encore sur Oli.'),
          ),
        ..._onOli.map((e) => ListTile(
              leading: CircleAvatar(child: Text(_initial(e.displayName))),
              title: Text(e.displayName),
              subtitle: Text(e.phone),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            )),
        _sectionTitle('Inviter sur Oli (${_notOnOli.length})'),
        ..._notOnOli.map((e) => ListTile(
              leading: CircleAvatar(child: Text(_initial(e.displayName))),
              title: Text(e.displayName),
              subtitle: Text(e.phone),
              trailing: TextButton(onPressed: _invite, child: const Text('Inviter')),
            )),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  String _initial(String name) => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}
