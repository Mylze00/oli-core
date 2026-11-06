import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wallet_provider.dart';
import '../models/transaction_model.dart';
import '../services/receipt_service.dart';
import '../widgets/wallet_action_sheets.dart';

/// Couleurs adaptées au thème clair ou sombre.
class _Palette {
  final bool isDark;
  _Palette(this.isDark);

  Color get bg => isDark ? const Color(0xFF0B0F1A) : const Color(0xFFF5F7FA);
  Color get surface => isDark ? const Color(0xFF161B2A) : Colors.white;
  Color get text => isDark ? Colors.white : const Color(0xFF1A1F2E);
  Color get muted => isDark ? Colors.white60 : Colors.black54;
  Color get divider => isDark ? Colors.white12 : Colors.black12;

  static const Color green = Color(0xFF22C55E);
  static const Color red = Color(0xFFEF4444);
  static const Color amber = Color(0xFFF59E0B);
  static const Color blue = Color(0xFF3B82F6);
  static const Color grey = Color(0xFF94A3B8);
}

enum _Filter { all, incoming, outgoing }

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _balanceVisible = true;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(walletProvider.notifier).loadWalletData());
  }

  Future<void> _refresh() => ref.read(walletProvider.notifier).loadWalletData();

  @override
  Widget build(BuildContext context) {
    final c = _Palette(Theme.of(context).brightness == Brightness.dark);
    final walletState = ref.watch(walletProvider);
    final all = walletState.transactions;

    final filtered = all.where((t) {
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.incoming:
          return t.amount > 0;
        case _Filter.outgoing:
          return t.amount < 0;
      }
    }).toList();

    final totalIn = all
        .where((t) => t.amount > 0 && t.status == 'completed')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalOut = all
        .where((t) => t.amount < 0 && t.status == 'completed')
        .fold<double>(0, (sum, t) => sum + t.amount.abs());

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Mon Wallet Oli'),
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _balanceCard(walletState.balance),
            if (walletState.error != null) _errorBanner(c),
            _summaryRow(c, totalIn, totalOut),
            _filterRow(c),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Mouvements (${filtered.length})',
                style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (walletState.isLoading && all.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              _emptyState(c)
            else
              ..._groupByDay(filtered).expand((group) => [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(group.key, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    ...group.value.map((t) => _txTile(c, t)),
                  ]),
          ],
        ),
      ),
    );
  }

  // ── Carte de solde + actions ───────────────────────────────────────────────
  Widget _balanceCard(double balance) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1E6FBF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(_balanceVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white70),
                onPressed: () => setState(() => _balanceVisible = !_balanceVisible),
              ),
            ],
          ),
          Text(
            _balanceVisible ? '${balance.toStringAsFixed(0)} FC' : '••••• FC',
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _actionButton(Icons.add, 'Dépôt', () => showWalletSheet(context, const RechargerSheet())),
              _actionButton(Icons.arrow_upward_rounded, 'Retrait', () => showWalletSheet(context, const RetirerSheet())),
              _actionButton(Icons.send_rounded, 'Envoyer', () => showWalletSheet(context, const EnvoyerSheet())),
              _actionButton(Icons.qr_code_rounded, 'Recevoir', () => showWalletSheet(context, const RecevoirSheet())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Bandeau d'erreur lisible (sans détail technique) ───────────────────────
  Widget _errorBanner(_Palette c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Palette.red.withValues(alpha: c.isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Palette.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _Palette.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Impossible d\'actualiser vos mouvements pour le moment. Tirez vers le bas pour réessayer.',
              style: TextStyle(color: c.text, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Totaux ────────────────────────────────────────────────────────────────
  Widget _summaryRow(_Palette c, double totalIn, double totalOut) {
    Widget card(String label, double value, Color color, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(color: c.muted, fontSize: 11)),
                      Text('${value.toStringAsFixed(0)} FC',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          card('Entrées (chargées)', totalIn, _Palette.green, Icons.call_received_rounded),
          const SizedBox(width: 10),
          card('Sorties (chargées)', totalOut, _Palette.red, Icons.call_made_rounded),
        ],
      ),
    );
  }

  // ── Filtres ───────────────────────────────────────────────────────────────
  Widget _filterRow(_Palette c) {
    const labels = {
      _Filter.all: 'Tous',
      _Filter.incoming: 'Entrées',
      _Filter.outgoing: 'Sorties',
    };
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _Filter.values.map((f) {
          final selected = f == _filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[f]!),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f),
              selectedColor: const Color(0xFF1E6FBF),
              backgroundColor: c.surface,
              side: BorderSide.none,
              labelStyle: TextStyle(
                color: selected ? Colors.white : c.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyState(_Palette c) => Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: c.muted),
            const SizedBox(height: 12),
            Text('Aucun mouvement', style: TextStyle(color: c.muted, fontSize: 16)),
          ],
        ),
      );

  // ── Un mouvement ──────────────────────────────────────────────────────────
  Widget _txTile(_Palette c, WalletTransaction t) {
    final info = _txInfo(t);
    final sign = t.amount >= 0 ? '+' : '-';
    final valueColor = t.amount >= 0 ? _Palette.green : _Palette.red;

    return InkWell(
      onTap: () => _showDetail(c, t),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: info.color.withValues(alpha: 0.15),
              child: Icon(info.icon, color: info.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.label, style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
                  if (t.description.isNotEmpty)
                    Text(t.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.muted, fontSize: 12)),
                  Text(_fmtDateTime(t.createdAt), style: TextStyle(color: c.muted, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign${t.amount.abs().toStringAsFixed(0)} ${t.currency}',
                  style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                _statusChip(t.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'completed' => ('Complété', _Palette.green),
      'pending' => ('En attente', _Palette.amber),
      'failed' => ('Échoué', _Palette.red),
      'cancelled' => ('Annulé', _Palette.grey),
      'reversed' => ('Annulé (remboursé)', _Palette.grey),
      _ => (status, _Palette.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  // ── Fiche détaillée d'un mouvement ────────────────────────────────────────
  void _showDetail(_Palette c, WalletTransaction t) {
    final info = _txInfo(t);
    final sign = t.amount >= 0 ? '+' : '-';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: info.color.withValues(alpha: 0.15),
                  child: Icon(info.icon, color: info.color),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(info.label, style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$sign${t.amount.abs().toStringAsFixed(0)} ${t.currency}',
              style: TextStyle(
                color: t.amount >= 0 ? _Palette.green : _Palette.red,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _kv(c, 'Statut', '', statusWidget: _statusChip(t.status)),
            _kv(c, 'Date', _fmtDateTime(t.createdAt, seconds: true)),
            _kv(c, 'Solde avant', '${t.balanceBefore.toStringAsFixed(0)} ${t.currency}'),
            _kv(c, 'Solde après', '${t.balanceAfter.toStringAsFixed(0)} ${t.currency}'),
            if (t.feeFC != null) _kv(c, 'Frais', '${t.feeFC!.toStringAsFixed(0)} ${t.currency}'),
            if (t.netFC != null) _kv(c, 'Montant net', '${t.netFC!.toStringAsFixed(0)} ${t.currency}'),
            if (t.provider != null && t.provider!.isNotEmpty) _kv(c, 'Opérateur', t.provider!),
            if (t.phoneNumber != null) _kv(c, 'Téléphone', _maskPhone(t.phoneNumber!)),
            if (t.orderId != null) _kv(c, 'Commande', '#${t.orderId}'),
            if (t.reference != null && t.reference!.isNotEmpty) _kv(c, 'Référence', t.reference!),
            if (t.description.isNotEmpty) _kv(c, 'Description', t.description),
            _kv(c, 'Type technique', t.type),
            _kv(c, 'Identifiant', '#${t.id}'),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => receiptService.showReceipt(context, t),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Voir le reçu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(_Palette c, String label, String value, {Widget? statusWidget}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: c.muted, fontSize: 13))),
          Expanded(
            child: statusWidget ??
                Text(value, style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── Utilitaires ───────────────────────────────────────────────────────────
  ({String label, IconData icon, Color color}) _txInfo(WalletTransaction t) {
    switch (t.type) {
      case 'deposit':
      case 'deposit_pending':
        return (label: 'Recharge Mobile Money', icon: Icons.add_circle_outline, color: _Palette.green);
      case 'withdrawal':
      case 'withdrawal_pending':
        return (label: 'Retrait Mobile Money', icon: Icons.arrow_upward_rounded, color: _Palette.red);
      case 'transfer':
        return t.amount >= 0
            ? (label: 'Argent reçu', icon: Icons.call_received_rounded, color: _Palette.green)
            : (label: 'Envoi d\'argent', icon: Icons.send_rounded, color: _Palette.blue);
      case 'payment':
        return (label: 'Achat', icon: Icons.shopping_bag_outlined, color: _Palette.red);
      case 'refund':
        return (label: 'Remboursement', icon: Icons.undo_rounded, color: _Palette.green);
      case 'reward':
        return (label: 'Récompense', icon: Icons.card_giftcard_rounded, color: _Palette.amber);
      case 'credit':
        return (label: 'Vente', icon: Icons.storefront_outlined, color: _Palette.green);
      case 'fee':
      case 'system_credit':
        return (label: 'Frais', icon: Icons.receipt_outlined, color: _Palette.grey);
      case 'escrow_lock':
      case 'escrow_release':
      case 'escrow_refund':
        return (label: 'Séquestre', icon: Icons.lock_outline, color: _Palette.amber);
      default:
        return (label: t.type, icon: Icons.swap_horiz, color: _Palette.grey);
    }
  }

  /// Regroupe les mouvements par jour (ordre conservé : du plus récent au plus ancien).
  List<MapEntry<String, List<WalletTransaction>>> _groupByDay(List<WalletTransaction> list) {
    final groups = <String, List<WalletTransaction>>{};
    for (final t in list) {
      groups.putIfAbsent(_fmtDay(t.createdAt), () => []).add(t);
    }
    return groups.entries.toList();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _fmtDay(DateTime d) {
    final l = d.toLocal();
    return '${_two(l.day)}/${_two(l.month)}/${l.year}';
  }

  String _fmtDateTime(DateTime d, {bool seconds = false}) {
    final l = d.toLocal();
    final base = '${_two(l.day)}/${_two(l.month)}/${l.year} ${_two(l.hour)}:${_two(l.minute)}';
    return seconds ? '$base:${_two(l.second)}' : base;
  }

  /// Affiche seulement les 4 derniers chiffres du numéro.
  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return phone;
    return '•••• ${digits.substring(digits.length - 4)}';
  }
}
