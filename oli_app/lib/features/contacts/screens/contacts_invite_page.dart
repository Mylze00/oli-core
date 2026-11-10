import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// Sur web, pas d'accès au carnet d'adresses : l'utilisateur saisit lui-même les numéros.
  bool _webEntry = false;
  final TextEditingController _phonesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _phonesController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (kIsWeb) {
      setState(() {
        _webEntry = true;
        _error = null;
      });
      return;
    }

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

      await _matchAndShow(byPhone);
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible de synchroniser vos contacts. Réessayez plus tard.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Interroge le serveur sur les numéros et sépare les contacts inscrits des autres.
  Future<void> _matchAndShow(Map<String, _ContactEntry> byPhone) async {
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
  }

  /// Web : l'utilisateur saisit les numéros (séparés par des virgules, espaces ou retours à la ligne).
  Future<void> _submitWebPhones() async {
    final raw = _phonesController.text.split(RegExp(r'[,;\s]+'));
    final byPhone = <String, _ContactEntry>{};
    var invalid = 0;
    for (final r in raw) {
      if (r.trim().isEmpty) continue;
      final normalized = normalizePhone(r);
      if (normalized == null) {
        invalid++;
      } else if (!byPhone.containsKey(normalized)) {
        byPhone[normalized] = _ContactEntry(phone: normalized, displayName: normalized);
      }
    }

    if (byPhone.isEmpty) {
      setState(() => _error = 'Aucun numéro valide. Exemple : 0812345678 ou +243812345678.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _matchAndShow(byPhone);
      if (invalid > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$invalid numéro(s) ignoré(s) car invalide(s).')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible de vérifier ces numéros. Réessayez plus tard.');
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

    if (_webEntry) return _buildWebEntry();

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

  Widget _buildWebEntry() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Saisissez les numéros de téléphone de vos contacts, séparés par des virgules ou des retours à la ligne. '
          'Les numéros sont envoyés pour vérifier s\'ils sont déjà inscrits sur Oli, puis ne sont pas conservés.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phonesController,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '0812345678, +243998765432',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _submitWebPhones, child: const Text('Vérifier les numéros')),
        if (_onOli.isNotEmpty || _notOnOli.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Déjà sur Oli (${_onOli.length}) : ${_onOli.map((e) => e.phone).join(', ')}'),
          const SizedBox(height: 8),
          Text('Non inscrits (${_notOnOli.length}) : ${_notOnOli.map((e) => e.phone).join(', ')}'),
        ],
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  String _initial(String name) => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}
