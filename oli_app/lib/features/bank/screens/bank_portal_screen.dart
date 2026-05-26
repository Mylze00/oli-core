import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bank_portal_provider.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _bg         = Color(0xFF060D1A);
const _surface    = Color(0xFF0E1E35);
const _card       = Color(0xFF112240);
const _accent     = Color(0xFF00F5C4);   // Vert crypto
const _accentB    = Color(0xFF4E8EFF);   // Bleu portefeuille
const _gold       = Color(0xFFFFD166);   // Or escrow
const _danger     = Color(0xFFFF4D6D);
const _textPri    = Colors.white;
const _textSec    = Color(0xFF8899B5);

// ─── Écran Principal ─────────────────────────────────────────────────────────

class BankPortalScreen extends ConsumerStatefulWidget {
  const BankPortalScreen({super.key});

  @override
  ConsumerState<BankPortalScreen> createState() => _BankPortalScreenState();
}

class _BankPortalScreenState extends ConsumerState<BankPortalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _verifyCtrl = TextEditingController();
  Map<String, dynamic>? _verifyResult;
  bool _verifying = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() => _selectedTab = _tabs.index));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bankPortalProvider.notifier).loadPortal();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _verifyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bankPortalProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                _buildAppBar(state),
              ],
              body: Column(
                children: [
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _OverviewTab(state: state),
                        _LedgerTab(state: state),
                        _EscrowTab(state: state),
                        _SecurityTab(
                          state: state,
                          verifyCtrl: _verifyCtrl,
                          verifyResult: _verifyResult,
                          verifying: _verifying,
                          onVerify: _verifyTx,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  SliverAppBar _buildAppBar(BankPortalState state) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: _bg,
      flexibleSpace: FlexibleSpaceBar(
        background: _HeroHeader(state: state),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: _textPri),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'OLI Bank',
        style: TextStyle(
          color: _textPri,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 1.2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _accent),
          onPressed: () => ref.read(bankPortalProvider.notifier).loadPortal(),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      (Icons.dashboard_rounded, 'Vue'),
      (Icons.receipt_long_rounded, 'Ledger'),
      (Icons.lock_rounded, 'Escrow'),
      (Icons.security_rounded, 'Sécurité'),
    ];
    return Container(
      color: _bg,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _tabs.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tabs[i].$1, size: 18,
                        color: selected ? _accent : _textSec),
                    const SizedBox(height: 3),
                    Text(tabs[i].$2,
                        style: TextStyle(
                          color: selected ? _accent : _textSec,
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        )),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _verifyTx() async {
    final hash = _verifyCtrl.text.trim();
    if (hash.isEmpty) return;
    setState(() { _verifying = true; _verifyResult = null; });
    final res = await ref.read(bankPortalProvider.notifier).verifyTx(hash);
    setState(() { _verifying = false; _verifyResult = res; });
  }
}

// ─── Hero Header ─────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final BankPortalState state;
  const _HeroHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fond dégradé
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF061428), Color(0xFF0A1F3A), Color(0xFF082030)],
            ),
          ),
        ),
        // Cercles de fond décoratifs
        Positioned(
          top: -40, right: -40,
          child: _GlowCircle(color: _accent, size: 180, opacity: 0.07),
        ),
        Positioned(
          bottom: -20, left: -30,
          child: _GlowCircle(color: _accentB, size: 140, opacity: 0.06),
        ),
        // Contenu
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Adresse OLI
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _accent.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hexagon_rounded, color: _accent, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            state.oliAddress ?? 'Non initialisé',
                            style: const TextStyle(
                              color: _accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (state.oliAddress != null) {
                          Clipboard.setData(ClipboardData(text: state.oliAddress!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Adresse OLI copiée'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: _accent,
                            ),
                          );
                        }
                      },
                      child: const Icon(Icons.copy_rounded, color: _accent, size: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Solde
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${state.walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _textPri,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        state.currency ?? 'USD',
                        style: const TextStyle(color: _textSec, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Stats rapides
                Row(
                  children: [
                    _MiniStat(label: 'Déposé', value: '\$${state.totalDeposited.toStringAsFixed(0)}', color: _accent),
                    const SizedBox(width: 16),
                    _MiniStat(label: 'Retiré', value: '\$${state.totalWithdrawn.toStringAsFixed(0)}', color: _danger),
                    const SizedBox(width: 16),
                    _MiniStat(label: 'En escrow', value: '\$${state.fundsInEscrow.toStringAsFixed(0)}', color: _gold),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tab 1 : Vue d'ensemble ───────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final BankPortalState state;
  const _OverviewTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Score de confiance
        _SectionTitle('Score de Confiance', Icons.verified_user_rounded, _accentB),
        const SizedBox(height: 10),
        _TrustScoreCard(state: state),
        const SizedBox(height: 20),

        // Statistiques globales
        _SectionTitle('Statistiques', Icons.bar_chart_rounded, _accent),
        const SizedBox(height: 10),
        _StatGrid(state: state),
        const SizedBox(height: 20),

        // Dernière session
        _SectionTitle('Dernière Session', Icons.devices_rounded, _accentB),
        const SizedBox(height: 10),
        _LastSessionCard(state: state),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── Tab 2 : Grand Livre ──────────────────────────────────────────────────────

class _LedgerTab extends StatelessWidget {
  final BankPortalState state;
  const _LedgerTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.ledger.isEmpty) {
      return _EmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'Grand livre vide\nLes transactions apparaîtront ici',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.ledger.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _LedgerTile(entry: state.ledger[i]),
    );
  }
}

// ─── Tab 3 : Escrow ───────────────────────────────────────────────────────────

class _EscrowTab extends StatelessWidget {
  final BankPortalState state;
  const _EscrowTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.escrows.isEmpty) {
      return _EmptyState(
        icon: Icons.lock_open_rounded,
        message: 'Aucun fonds en séquestre\nVos escrows actifs s\'afficheront ici',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.escrows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _EscrowTile(entry: state.escrows[i]),
    );
  }
}

// ─── Tab 4 : Sécurité ─────────────────────────────────────────────────────────

class _SecurityTab extends StatelessWidget {
  final BankPortalState state;
  final TextEditingController verifyCtrl;
  final Map<String, dynamic>? verifyResult;
  final bool verifying;
  final VoidCallback onVerify;

  const _SecurityTab({
    required this.state,
    required this.verifyCtrl,
    required this.verifyResult,
    required this.verifying,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sessions récentes
        _SectionTitle('Sessions Récentes', Icons.history_rounded, _accentB),
        const SizedBox(height: 10),
        ...state.sessions.map((s) => _SessionTile(session: s)),
        const SizedBox(height: 24),

        // Vérificateur de transaction
        _SectionTitle('Vérifier une Transaction', Icons.verified_rounded, _accent),
        const SizedBox(height: 10),
        _TxVerifier(
          ctrl: verifyCtrl,
          result: verifyResult,
          loading: verifying,
          onVerify: onVerify,
        ),
        const SizedBox(height: 24),

        // Clé publique OLI
        _SectionTitle('Identité Cryptographique', Icons.key_rounded, _gold),
        const SizedBox(height: 10),
        _CryptoIdentityCard(state: state),
      ],
    );
  }
}

// ─── Widgets de composants ────────────────────────────────────────────────────

class _TrustScoreCard extends StatelessWidget {
  final BankPortalState state;
  const _TrustScoreCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final score = state.trustScore ?? 0;
    final risk  = state.fraudRiskLevel ?? 'low';
    final color = risk == 'low' ? _accent
        : risk == 'medium' ? _gold
        : _danger;
    final label = risk == 'low' ? 'Utilisateur de confiance'
        : risk == 'medium' ? 'Surveillance recommandée'
        : 'Risque élevé';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Arc de score
              SizedBox(
                width: 80, height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(color),
                      strokeWidth: 8,
                    ),
                    Text(
                      score.toStringAsFixed(0),
                      style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Score OLI Bank', style: TextStyle(color: _textSec, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(risk.toUpperCase(),
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final BankPortalState state;
  const _StatGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Transactions', '${state.totalTransactions}', Icons.swap_horiz_rounded, _accentB),
      ('Escrows actifs', '${state.activeEscrows}', Icons.lock_rounded, _gold),
      ('En séquestre', '\$${state.fundsInEscrow.toStringAsFixed(0)}', Icons.account_balance_rounded, _gold),
      ('Wallet actif', state.bankActive ? 'Oui' : 'Non', Icons.check_circle_rounded, _accent),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 2,
      children: items.map((item) => _Card(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.$4.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.$3, color: item.$4, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.$1, style: const TextStyle(color: _textSec, fontSize: 10)),
                Text(item.$2, style: const TextStyle(color: _textPri, fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }
}

class _LastSessionCard extends StatelessWidget {
  final BankPortalState state;
  const _LastSessionCard({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.sessions.isEmpty) {
      return _Card(child: Text('Aucune session enregistrée',
          style: TextStyle(color: _textSec, fontSize: 12)));
    }
    final s = state.sessions.first;
    return _Card(
      child: Row(
        children: [
          Icon(
            s.deviceType == 'android' ? Icons.android_rounded
                : s.deviceType == 'ios' ? Icons.apple_rounded
                : Icons.computer_rounded,
            color: _accentB, size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.deviceType.toUpperCase()} ${s.deviceModel ?? ''}',
                    style: const TextStyle(color: _textPri, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 3),
                Text('${s.city ?? ''} ${s.country ?? ''}',
                    style: const TextStyle(color: _textSec, fontSize: 11)),
                Text('${s.actionCount} actions · ${s.financialActions} financières',
                    style: const TextStyle(color: _textSec, fontSize: 11)),
              ],
            ),
          ),
          if (s.isSuspicious)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('⚠️ Suspect',
                  style: TextStyle(color: _danger, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final LedgerEntry entry;
  const _LedgerTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isCredit = entry.amount >= 0;
    final color    = isCredit ? _accent : _danger;
    final icon     = isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_txLabel(entry.txType),
                        style: const TextStyle(color: _textPri, fontWeight: FontWeight.w700, fontSize: 13)),
                    if (entry.counterpartName != null)
                      Text('→ ${entry.counterpartName}',
                          style: const TextStyle(color: _textSec, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${isCredit ? '+' : ''}\$${entry.amount.abs().toStringAsFixed(2)}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
                  if (entry.feeAmount > 0)
                    Text('Frais: \$${entry.feeAmount.toStringAsFixed(2)}',
                        style: const TextStyle(color: _textSec, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Hash chaîné
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: entry.txHash));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hash copié'), behavior: SnackBarBehavior.floating),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, color: _textSec, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      entry.txHash,
                      style: const TextStyle(color: _textSec, fontSize: 9, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.copy_rounded, color: _textSec, size: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _txLabel(String type) {
    const labels = {
      'deposit':          'Recharge',
      'withdrawal':       'Retrait',
      'p2p_send':         'Envoi P2P',
      'p2p_receive':      'Réception P2P',
      'escrow_lock':      'Escrow bloqué',
      'escrow_release':   'Escrow libéré',
      'escrow_refund':    'Remboursement Escrow',
      'fee':              'Frais OLI',
      'refund':           'Remboursement',
      'reward':           'Récompense',
      'system_credit':    'Crédit Système',
    };
    return labels[type] ?? type;
  }
}

class _EscrowTile extends StatelessWidget {
  final EscrowEntry entry;
  const _EscrowTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return _Card(
      borderColor: _gold.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_rounded, color: _gold, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Commande #${entry.orderId}',
                        style: const TextStyle(color: _textPri, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(entry.escrowRef,
                        style: const TextStyle(color: _textSec, fontSize: 10)),
                  ],
                ),
              ),
              Text(
                '\$${entry.amountLocked.toStringAsFixed(2)}',
                style: const TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              _EscrowStat('Vendeur', '\$${entry.sellerAmount.toStringAsFixed(2)}', _accent),
              const SizedBox(width: 12),
              if (entry.delivererAmount > 0)
                _EscrowStat('Livreur', '\$${entry.delivererAmount.toStringAsFixed(2)}', _accentB),
              if (entry.delivererAmount > 0) const SizedBox(width: 12),
              _EscrowStat('Frais OLI', '\$${entry.oliFee.toStringAsFixed(2)}', _textSec),
            ],
          ),
        ],
      ),
    );
  }
}

class _EscrowStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _EscrowStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _textSec, fontSize: 10)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      );
}

class _SessionTile extends StatelessWidget {
  final SessionEntry session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: session.isSuspicious
              ? _danger.withOpacity(0.4)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          Icon(
            session.deviceType == 'android' ? Icons.android_rounded
                : session.deviceType == 'ios' ? Icons.apple_rounded
                : Icons.computer_rounded,
            color: session.isSuspicious ? _danger : _accentB,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.deviceModel ?? session.deviceType.toUpperCase(),
                    style: const TextStyle(color: _textPri, fontSize: 12, fontWeight: FontWeight.w700)),
                Text('${session.city ?? ''} · ${session.actionCount} actions',
                    style: const TextStyle(color: _textSec, fontSize: 10)),
              ],
            ),
          ),
          if (session.isSuspicious)
            const Icon(Icons.warning_amber_rounded, color: _danger, size: 16),
        ],
      ),
    );
  }
}

class _TxVerifier extends StatelessWidget {
  final TextEditingController ctrl;
  final Map<String, dynamic>? result;
  final bool loading;
  final VoidCallback onVerify;

  const _TxVerifier({
    required this.ctrl,
    required this.result,
    required this.loading,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = result?['valid'] == true;
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.tag_rounded, color: _textSec, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  style: const TextStyle(color: _textPri, fontSize: 12, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Hash ou TX ID à vérifier',
                    hintStyle: TextStyle(color: _textSec, fontSize: 12),
                  ),
                ),
              ),
              GestureDetector(
                onTap: loading ? null : onVerify,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: loading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _accent))
                      : const Text('Vérifier', style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 12),
          _Card(
            borderColor: (isValid ? _accent : _danger).withOpacity(0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isValid ? _accent : _danger,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isValid ? 'Transaction valide ✓' : 'Transaction invalide ✗',
                      style: TextStyle(color: isValid ? _accent : _danger, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (result!['txType'] != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow('Type', result!['txType'].toString()),
                  _InfoRow('Montant', '\$${result!['amount']}'),
                  _InfoRow('Statut', result!['status']?.toString() ?? '-'),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CryptoIdentityCard extends StatelessWidget {
  final BankPortalState state;
  const _CryptoIdentityCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return _Card(
      borderColor: _gold.withOpacity(0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, color: _gold, size: 20),
              const SizedBox(width: 8),
              const Text('Identité OLI Bank',
                  style: TextStyle(color: _textPri, fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('RSA-2048 + AES-256',
                    style: TextStyle(color: _accent, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow('Adresse OLI', state.oliAddress ?? 'Non défini'),
          _InfoRow('Chiffrement', 'AES-256-CBC côté serveur'),
          _InfoRow('Signature', 'SHA-256 + RSA-2048'),
          _InfoRow('Chaîne', 'Hash chaîné (blockchain légère)'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '🔐 Vos clés privées ne sont jamais transmises à votre appareil. '
              'Chaque transaction est signée numériquement et son intégrité est vérifiable.',
              style: TextStyle(color: _textSec, fontSize: 10, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Petits helpers UI ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionTitle(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12,
              letterSpacing: 0.5)),
        ],
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  const _Card({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.08)),
        ),
        child: child,
      );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _textSec, fontSize: 9)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      );
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _GlowCircle({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(color: _textSec, fontSize: 11)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(color: _textPri, fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.white.withOpacity(0.12)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13, height: 1.6),
            ),
          ],
        ),
      );
}
