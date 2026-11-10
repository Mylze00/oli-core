import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/router/network/dio_provider.dart';
import '../../../core/theme/oli_glass.dart';
import '../../auth/providers/auth_controller.dart';
import '../../chat/chat_page.dart';
import '../../../core/user/user_provider.dart';
import '../services/contacts_match_service.dart';
import '../utils/phone_normalizer.dart';

/// Un contact du carnet, avec son numéro normalisé et son compte Oli s'il en a un.
class _AddressBookEntry {
  final String phone;
  final String displayName;
  final ContactMatch? account;

  const _AddressBookEntry({required this.phone, required this.displayName, this.account});
}

/// Contacts de l'utilisateur : ajout par numéro, ouverture de la discussion et invitation.
/// Les contacts non inscrits ne quittent jamais le téléphone.
class ContactsInvitePage extends ConsumerStatefulWidget {
  const ContactsInvitePage({super.key});

  @override
  ConsumerState<ContactsInvitePage> createState() => _ContactsInvitePageState();
}

class _ContactsInvitePageState extends ConsumerState<ContactsInvitePage> {
  static const String _inviteBaseUrl = 'https://oli-core.web.app/';
  static const String _invalidNumberMessage = 'Numéro invalide. Exemple : 0812345678 ou +243812345678.';

  final TextEditingController _numberController = TextEditingController();

  List<ContactMatch> _contacts = [];
  bool _isLoadingContacts = true;
  bool _contactsLoadFailed = false;

  bool _isAdding = false;
  String? _numberError;
  String? _notOnOliPhone;

  bool _isSyncing = false;
  bool _hasSynced = false;
  bool _permissionDenied = false;
  String? _syncError;
  List<_AddressBookEntry> _bookOnOli = [];
  List<_AddressBookEntry> _bookNotOnOli = [];

  ContactsMatchService get _service => ContactsMatchService(ref.read(dioProvider));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContacts());
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoadingContacts = true;
      _contactsLoadFailed = false;
    });
    try {
      final contacts = await _service.fetchContacts();
      if (mounted) setState(() => _contacts = contacts);
    } catch (e) {
      debugPrint('Erreur de chargement des contacts: $e');
      if (mounted) setState(() => _contactsLoadFailed = true);
    } finally {
      if (mounted) setState(() => _isLoadingContacts = false);
    }
  }

  void _storeContact(ContactMatch contact) {
    _contacts = [..._contacts.where((c) => c.id != contact.id), contact]
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addNumber() async {
    final phone = normalizePhone(_numberController.text.trim());
    if (phone == null) {
      setState(() {
        _numberError = _invalidNumberMessage;
        _notOnOliPhone = null;
      });
      return;
    }

    setState(() {
      _isAdding = true;
      _numberError = null;
      _notOnOliPhone = null;
    });
    try {
      final contact = await _service.addContact(phone);
      if (!mounted) return;
      setState(() {
        _storeContact(contact);
        _numberController.clear();
      });
      _showMessage('${contact.displayName} a été ajouté à vos contacts');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _applyAddError(e, phone));
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  void _applyAddError(DioException error, String phone) {
    final code = error.response?.data is Map ? error.response?.data['code'] : null;
    switch (code) {
      case 'not_on_oli':
        _notOnOliPhone = phone;
      case 'own_number':
        _numberError = "C'est votre propre numéro.";
      case 'invalid_phone':
        _numberError = _invalidNumberMessage;
      case 'rate_limited':
        _numberError = "Trop d'ajouts de contacts. Réessayez plus tard.";
      default:
        _numberError = "Impossible d'ajouter ce contact. Réessayez plus tard.";
    }
  }

  Future<void> _addFromAddressBook(_AddressBookEntry entry) async {
    try {
      final contact = await _service.addContact(entry.phone);
      if (mounted) setState(() => _storeContact(contact));
    } on DioException {
      if (mounted) _showMessage("Impossible d'ajouter ce contact. Réessayez plus tard.");
    }
  }

  Future<void> _removeContact(ContactMatch contact) async {
    try {
      await _service.removeContact(contact.id);
      if (mounted) setState(() => _contacts = _contacts.where((c) => c.id != contact.id).toList());
    } on DioException {
      if (mounted) _showMessage('Impossible de retirer ce contact. Réessayez plus tard.');
    }
  }

  void _openChat(ContactMatch contact) {
    final myId = ref.read(userProvider).value?.id.toString();
    if (myId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          myId: myId,
          otherId: contact.id.toString(),
          otherName: contact.displayName,
          otherAvatarUrl: contact.avatarUrl,
        ),
      ),
    );
  }

  Future<void> _syncAddressBook() async {
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
    if (consent != true || !mounted) return;

    setState(() {
      _isSyncing = true;
      _syncError = null;
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
      final namesByPhone = <String, String>{};
      for (final c in contacts) {
        for (final p in c.phones) {
          final normalized = normalizePhone(p.number);
          if (normalized != null) namesByPhone.putIfAbsent(normalized, () => c.displayName);
        }
      }

      final matches = await _service.matchPhones(namesByPhone.keys.toList());
      final accounts = {for (final m in matches) m.phone: m};
      final entries = namesByPhone.entries
          .map((e) => _AddressBookEntry(phone: e.key, displayName: e.value, account: accounts[e.key]))
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

      if (mounted) {
        setState(() {
          _bookOnOli = entries.where((e) => e.account != null).toList();
          _bookNotOnOli = entries.where((e) => e.account == null).toList();
          _hasSynced = true;
        });
      }
    } catch (e) {
      debugPrint('Erreur de synchronisation des contacts: $e');
      if (mounted) setState(() => _syncError = 'Impossible de synchroniser vos contacts. Réessayez plus tard.');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
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
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Inviter par lien',
            onPressed: _invite,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadContacts,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildAddByNumber(),
            _sectionTitle('Mes contacts${_isLoadingContacts ? '' : ' (${_contacts.length})'}'),
            _buildMyContacts(),
            if (!kIsWeb) ...[
              _sectionTitle('Carnet du téléphone'),
              _buildAddressBook(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddByNumber() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _numberController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _isAdding ? null : _addNumber(),
                  decoration: InputDecoration(
                    labelText: 'Numéro',
                    hintText: '0812345678',
                    errorText: _numberError,
                    errorMaxLines: 2,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                height: 56,
                child: ElevatedButton(
                  style: oliPrimaryButtonStyle(),
                  onPressed: _isAdding ? null : _addNumber,
                  child: _isAdding
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Ajouter'),
                ),
              ),
            ],
          ),
          if (_notOnOliPhone != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_off_outlined),
              title: Text("$_notOnOliPhone n'est pas encore sur Oli"),
              trailing: TextButton(onPressed: _invite, child: const Text('Inviter')),
            ),
        ],
      ),
    );
  }

  Widget _buildMyContacts() {
    if (_isLoadingContacts) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_contactsLoadFailed) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Impossible de charger vos contacts.', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadContacts, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_contacts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('Aucun contact pour le moment. Ajoutez-en un avec son numéro.'),
      );
    }
    return Column(
      children: _contacts
          .map((contact) => ListTile(
                leading: _avatar(contact.displayName, contact.avatarUrl),
                title: Text(contact.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(contact.phone),
                onTap: () => _openChat(contact),
                trailing: PopupMenuButton<void>(
                  tooltip: 'Options du contact',
                  itemBuilder: (_) => [
                    PopupMenuItem<void>(
                      onTap: () => _removeContact(contact),
                      child: const Text('Retirer des contacts'),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildAddressBook() {
    if (_isSyncing) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final message = _permissionDenied
        ? "L'accès à vos contacts est refusé. Vous pouvez l'autoriser dans les réglages de votre téléphone."
        : _syncError;

    if (!_hasSynced || message != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message != null) ...[
              Text(message),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _syncAddressBook,
              icon: const Icon(Icons.contacts_outlined),
              label: const Text('Trouver mes contacts du téléphone'),
            ),
          ],
        ),
      );
    }

    final savedIds = _contacts.map((c) => c.id).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_bookOnOli.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Aucun de vos contacts n\'est encore sur Oli.'),
          ),
        ..._bookOnOli.map((entry) {
          final account = entry.account!;
          return ListTile(
            leading: _avatar(entry.displayName, account.avatarUrl),
            title: Text(entry.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(entry.phone),
            onTap: () => _openChat(account),
            trailing: savedIds.contains(account.id)
                ? const Icon(Icons.check_circle, color: Colors.green)
                : TextButton(onPressed: () => _addFromAddressBook(entry), child: const Text('Ajouter')),
          );
        }),
        ..._bookNotOnOli.map((entry) => ListTile(
              leading: _avatar(entry.displayName, null),
              title: Text(entry.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(entry.phone),
              trailing: TextButton(onPressed: _invite, child: const Text('Inviter')),
            )),
      ],
    );
  }

  Widget _avatar(String name, String? avatarUrl) {
    final hasImage = avatarUrl != null && avatarUrl.startsWith('http');
    return CircleAvatar(
      backgroundImage: hasImage ? NetworkImage(avatarUrl) : null,
      onBackgroundImageError: hasImage ? (_, __) {} : null,
      child: hasImage ? null : Text(_initial(name)),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  String _initial(String name) => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}
