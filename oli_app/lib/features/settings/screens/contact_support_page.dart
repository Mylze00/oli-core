import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';

class ContactSupportPage extends ConsumerStatefulWidget {
  const ContactSupportPage({super.key});

  @override
  ConsumerState<ContactSupportPage> createState() => _ContactSupportPageState();
}

class _ContactSupportPageState extends ConsumerState<ContactSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedCategory = 'general';
  bool _isLoading = false;
  bool _isLoadingTickets = true;
  List<dynamic> _myTickets = [];

  // Onglets
  int _tabIndex = 0;

  final List<Map<String, String>> _categories = [
    {'value': 'general', 'label': '💬 Question générale'},
    {'value': 'order', 'label': '📦 Problème de commande'},
    {'value': 'payment', 'label': '💳 Paiement / Portefeuille'},
    {'value': 'delivery', 'label': '🚚 Livraison'},
    {'value': 'account', 'label': '👤 Mon compte'},
    {'value': 'bug', 'label': '🐛 Bug / Problème technique'},
    {'value': 'other', 'label': '📝 Autre'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchMyTickets();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyTickets() async {
    setState(() => _isLoadingTickets = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(ApiConfig.supportTickets);
      if (response.statusCode == 200 && response.data is List) {
        setState(() => _myTickets = response.data);
      }
    } catch (e) {
      debugPrint('Erreur chargement tickets: $e');
    } finally {
      setState(() => _isLoadingTickets = false);
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(ApiConfig.supportTickets, data: {
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'category': _selectedCategory,
      });

      if (response.statusCode == 201) {
        if (mounted) {
          _subjectController.clear();
          _messageController.clear();
          setState(() {
            _selectedCategory = 'general';
            _tabIndex = 1; // Go to my tickets tab
          });
          _fetchMyTickets();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Votre message a été envoyé ! Nous vous répondrons rapidement.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.response?.data?['error'] ?? 'Impossible d\'envoyer le message'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Contacter Service Oli'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _buildTab('Nouveau message', 0),
              _buildTab('Mes tickets (${_myTickets.length})', 1),
            ],
          ),
        ),
      ),
      body: _tabIndex == 0 ? _buildNewTicketForm(isDark) : _buildMyTickets(isDark),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _tabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive
                  ? Colors.blue
                  : (isDark ? Colors.white54 : Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewTicketForm(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white38 : Colors.grey.shade400;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.headset_mic, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comment pouvons-nous vous aider ?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Notre équipe vous répondra dans les plus brefs délais.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Catégorie
            Text('Catégorie', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: cardColor,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: const InputDecoration(border: InputBorder.none),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat['value'],
                    child: Text(cat['label']!),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v ?? 'general'),
              ),
            ),

            const SizedBox(height: 16),

            // Sujet
            Text('Sujet', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subjectController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Ex: Problème avec ma commande #1234',
                hintStyle: TextStyle(color: hintColor),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Veuillez entrer un sujet' : null,
            ),

            const SizedBox(height: 16),

            // Message
            Text('Message', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageController,
              style: TextStyle(color: textColor),
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Décrivez votre problème en détail...',
                hintStyle: TextStyle(color: hintColor),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
              ),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Le message doit contenir au moins 10 caractères' : null,
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Envoyer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTickets(bool isDark) {
    if (_isLoadingTickets) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myTickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun ticket',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vos messages de support apparaîtront ici.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTickets.length,
        itemBuilder: (context, index) {
          final ticket = _myTickets[index];
          return _buildTicketCard(ticket, isDark);
        },
      ),
    );
  }

  Widget _buildTicketCard(dynamic ticket, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final status = ticket['status'] ?? 'open';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'open':
        statusColor = Colors.blue;
        statusLabel = 'Ouvert';
        statusIcon = Icons.circle_outlined;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'En attente';
        statusIcon = Icons.access_time;
        break;
      case 'resolved':
        statusColor = Colors.green;
        statusLabel = 'Résolu';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = status;
        statusIcon = Icons.circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket['subject'] ?? 'Sans sujet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ticket['last_message'] != null) ...[
            const SizedBox(height: 8),
            Text(
              ticket['last_message'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: isDark ? Colors.white24 : Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                _formatDate(ticket['updated_at'] ?? ticket['created_at']),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                ),
              ),
              const Spacer(),
              if (ticket['message_count'] != null)
                Text(
                  '${ticket['message_count']} message(s)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}
