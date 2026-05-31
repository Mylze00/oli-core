import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'chat_page.dart';
import 'socket_service.dart';
import 'providers/inbox_providers.dart';
import '../feed/presentation/feed_tab_view.dart';
import '../../config/api_config.dart';
import '../../core/user/user_provider.dart';
import '../../core/storage/secure_storage_service.dart';

// Provider pour les conversations migré vers inbox_providers.dart pour le cache offline-first

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  int _selectedIndex = 0; // 0: Privé, 1: Market
  InboxFilter _filter = InboxFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _multiSelectMode = false;
  final Set<String> _selectedConvIds = {};

  // Favoris locaux (Set de otherId)
  final Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _initSocket();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initSocket() async {
    final user = ref.read(userProvider).value;
    if (user != null) {
      final socketService = ref.read(socketServiceProvider);
      await socketService.connect(user.id.toString());
      
      socketService.onMessage((data) {
        ref.read(inboxConversationsProvider.notifier).fetchConversations();
      });
    }
  }

  Future<void> _pickContact() async {
    // 1. Demander la permission
    if (await Permission.contacts.request().isGranted) {
      try {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          debugPrint("Contact sélectionné: ${contact.displayName}");
          
          final phone = contact.phones.isNotEmpty ? contact.phones.first.number : null;
          if (phone != null) {
             // Ici on pourrait appeler une fonction pour chercher l'utilisateur par téléphone
             // _checkUserByPhone(phone);
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("Contact sélectionné: ${contact.displayName} ($phone)")),
             );
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Ce contact n'a pas de numéro de téléphone")),
             );
          }
        }
      } catch (e) {
        debugPrint("Erreur contacts: $e");
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Erreur lors de la sélection: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Permission contacts refusée")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    final conversationsAsync = ref.watch(inboxConversationsProvider);
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white : Colors.black;
    final containerColor = isDark ? Colors.white.withOpacity(0.08) : Colors.grey[100];
    final bgImage = isDark ? "assets/images/chat_bg_new.png" : "assets/images/chat_bg_new blanc.png";

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: _multiSelectMode
            ? Text(
                '${_selectedConvIds.length} sélectionné${_selectedConvIds.length > 1 ? 's' : ''}',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              )
            : Text(
                'Discussions',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
        leading: _multiSelectMode
            ? IconButton(
                icon: Icon(Icons.close, color: iconColor),
                onPressed: () => setState(() {
                  _multiSelectMode = false;
                  _selectedConvIds.clear();
                }),
              )
            : null,
        actions: _multiSelectMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Supprimer la sélection',
                  onPressed: _selectedConvIds.isEmpty ? null : () {
                    setState(() {
                      _multiSelectMode = false;
                      _selectedConvIds.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conversations supprimées')),
                    );
                  },
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.checklist_rounded, color: iconColor),
                  tooltip: 'Multi-sélection',
                  onPressed: () => setState(() {
                    _multiSelectMode = true;
                  }),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: iconColor),
                  onPressed: () {},
                ),
              ],
      ),
      body: Column(
        children: [
          // Search + Tabs + Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: bgColor,
            child: Column(
              children: [
                // Search Bar
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un message...',
                      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                      prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Type tabs (Privé / Market / Fil)
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(children: [
                    _buildTabItem(0, 'Privé'),
                    _buildTabItem(1, 'Market Chat'),
                    _buildTabItem(2, 'Fil'),
                  ]),
                ),
                const SizedBox(height: 10),

                // Filter bar
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _selectedIndex == 2
                        ? [
                            _FilterChip(label: 'Pour vous', selected: true, onTap: () {}),
                            const SizedBox(width: 8),
                            _FilterChip(label: 'Abonnement', selected: false, onTap: () {}), // Par défaut non sélectionné sauf si on veut l'effet inverse
                            const SizedBox(width: 8),
                            _FilterChip(label: '...', selected: false, onTap: () {}),
                          ]
                        : [
                            _FilterChip(label: 'Tous', icon: Icons.inbox_outlined, selected: _filter == InboxFilter.all, onTap: () => setState(() => _filter = InboxFilter.all)),
                            const SizedBox(width: 8),
                            _FilterChip(label: 'Non lus', icon: Icons.mark_chat_unread_outlined, selected: _filter == InboxFilter.unread, onTap: () => setState(() => _filter = InboxFilter.unread)),
                            const SizedBox(width: 8),
                            _FilterChip(label: 'Favoris', icon: Icons.star_outline_rounded, selected: _filter == InboxFilter.favorites, onTap: () => setState(() => _filter = InboxFilter.favorites)),
                            const SizedBox(width: 8),
                            _FilterChip(label: 'Archives', icon: Icons.archive_outlined, selected: _filter == InboxFilter.archives, onTap: () => setState(() => _filter = InboxFilter.archives)),
                          ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // 2. Contenu (Fil d'actualité OU Liste des Conversations)
          Expanded(
            child: _selectedIndex == 2 
              ? const FeedTabView() // Affiche le fil d'actualité si l'onglet 2 est sélectionné
              : Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(bgImage),
                  fit: BoxFit.cover,
                  opacity: isDark ? 0.40 : 0.8,
                ),
              ),
              child: conversationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text("Erreur: $err")),
                data: (allConversations) {
                  final archived = ref.watch(archivedConversationsProvider);
                  final pinned = ref.watch(pinnedConversationsProvider);

                  // 1. Filtre type (Privé / Market)
                  final filtered = allConversations.where((c) {
                    final hasProduct = c['product_id'] != null;
                    final matchesType = _selectedIndex == 1 ? hasProduct : !hasProduct;
                    final otherName = (c['other_name'] ?? '').toString().toLowerCase();
                    final lastMsg = (c['last_message'] ?? '').toString().toLowerCase();
                    final matchesSearch = otherName.contains(_searchQuery) || lastMsg.contains(_searchQuery);
                    return matchesType && matchesSearch;
                  }).toList();

                  // 2. Déduplication par other_id
                  final Map<String, List<Map<String, dynamic>>> grouped = {};
                  for (final c in filtered) {
                    final key = c['other_id']?.toString() ?? 'unknown';
                    grouped.putIfAbsent(key, () => []).add(c);
                  }
                  var deduped = grouped.values.map((list) => list.first).toList();

                  // 3. InboxFilter
                  deduped = deduped.where((c) {
                    final otherId = c['other_id']?.toString() ?? '';
                    switch (_filter) {
                      case InboxFilter.all:
                        return !archived.contains(otherId);
                      case InboxFilter.unread:
                        return (c['unread_count'] ?? 0) > 0 && !archived.contains(otherId);
                      case InboxFilter.favorites:
                        return _favorites.contains(otherId);
                      case InboxFilter.archives:
                        return archived.contains(otherId);
                    }
                  }).toList();

                  // 4. Tri : épinglées en premier
                  deduped.sort((a, b) {
                    final aPin = pinned.contains(a['other_id']?.toString() ?? '');
                    final bPin = pinned.contains(b['other_id']?.toString() ?? '');
                    if (aPin && !bPin) return -1;
                    if (!aPin && bPin) return 1;
                    return 0;
                  });

                  final filteredConversations = deduped;

                  if (filteredConversations.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedIndex == 0 ? Icons.chat_bubble_outline : Icons.shopping_bag_outlined,
                            size: 60, 
                            color: Colors.grey[300]
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty 
                                ? "Aucun résultat trouvé"
                                : (_selectedIndex == 0 ? "Aucune conversation privée" : "Aucune conversation Market"),
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.read(inboxConversationsProvider.notifier).fetchConversations(),
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: filteredConversations.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
                      itemBuilder: (context, index) {
                        final conv = filteredConversations[index];
                        final convId = conv['conversation_id']?.toString() ?? 'conv_$index';

                        return Dismissible(
                          key: Key(convId),
                          // ── Swipe gauche → Archiver / Supprimer ─────────────────────
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            color: Colors.blue.shade600,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mark_chat_read_outlined, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Lu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // ── Swipe droite → Marquer lu/non-lu ─────────────────────
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.shade400,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('Supprimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                SizedBox(width: 8),
                                Icon(Icons.delete_outline, color: Colors.white),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.endToStart) {
                              // Swipe gauche = Supprimer (demander confirmation)
                              return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('Supprimer la conversation'),
                                  content: Text('Supprimer la conversation avec ${conv['other_name'] ?? 'cet utilisateur'} ?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Annuler'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ) ?? false;
                            } else {
                              // Swipe droite = Marquer comme lu (pas de dismiss réel)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.mark_chat_read, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Conversation avec ${conv['other_name'] ?? ''} marquée comme lue'),
                                    ],
                                  ),
                                  backgroundColor: Colors.blue.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              return false; // On ne dismissreel pas la tuile
                            }
                          },
                          onDismissed: (direction) {
                            // Confirmé uniquement pour endToStart (supprimer)
                            ref.read(inboxConversationsProvider.notifier).fetchConversations();
                          },
                          child: Row(
                            children: [
                              if (_multiSelectMode)
                                Checkbox(
                                  value: _selectedConvIds.contains(convId),
                                  activeColor: theme.primaryColor,
                                  onChanged: (bool? checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedConvIds.add(convId);
                                      } else {
                                        _selectedConvIds.remove(convId);
                                      }
                                    });
                                  },
                                ),
                              Expanded(
                                child: ConversationTile(
                                  conversation: conv,
                                  currentUserId: user.id.toString(),
                                  // Extra badge for duplicate conversations
                                  extraBadge: (() {
                                    final otherId = conv['other_id']?.toString() ?? '';
                                    final list = grouped[otherId] ?? [];
                                    final uniquePIds = list.map((c) => c['product_id']?.toString() ?? 'private').toSet();
                                    final count = uniquePIds.length;
                                    return count > 1 ? count : null;
                                  })(),
                                  onTap: () {
                                    if (_multiSelectMode) {
                                      setState(() {
                                        if (_selectedConvIds.contains(convId)) {
                                          _selectedConvIds.remove(convId);
                                        } else {
                                          _selectedConvIds.add(convId);
                                        }
                                      });
                                      return;
                                    }

                                    final otherId = conv['other_id']?.toString() ?? '';
                                    final dupeList = grouped[otherId] ?? [conv];

                                    if (dupeList.length > 1) {
                                      _showConversationSelector(context, dupeList, user.id.toString());
                                    } else {
                                      _openConversation(context, conv, user.id.toString());
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: FloatingActionButton(
                onPressed: _pickContact,
                backgroundColor: theme.primaryColor,
                child: const Icon(Icons.person_add, color: Colors.white),
              ),
            )
          : null, // Le FloatingActionButton du Fil est géré dans FeedTabView
    );
  }

  void _openConversation(BuildContext context, Map<String, dynamic> conv, String myUserId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          myId: myUserId,
          otherId: conv['other_id']?.toString() ?? '',
          otherName: conv['other_name'] ?? 'Utilisateur',
          productId: conv['product_id']?.toString(),
          productName: conv['product_name'],
          productImage: conv['product_image'],
          productPrice: double.tryParse(conv['product_price']?.toString() ?? '0'),
          otherAvatarUrl: conv['other_avatar'],
        ),
      ),
    ).then((_) => ref.read(inboxConversationsProvider.notifier).fetchConversations());
  }

  void _showConversationSelector(
    BuildContext context,
    List<Map<String, dynamic>> convList,
    String myUserId,
  ) {
    // Dédupliquer par product_id pour éviter de voir N fois le même produit
    final Map<String, Map<String, dynamic>> deduped = {};
    for (var c in convList) {
      final pKey = c['product_id']?.toString() ?? 'private';
      if (!deduped.containsKey(pKey)) deduped[pKey] = c;
    }
    final uniqueConvs = deduped.values.toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Conversations avec ${convList.first['other_name'] ?? 'cet utilisateur'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...uniqueConvs.map((conv) {
              final product = conv['product_name'];
              final lastMsg = conv['last_message'] ?? '';
              return ListTile(
                leading: Icon(
                  product != null ? Icons.shopping_bag_outlined : Icons.chat_bubble_outline,
                  color: product != null ? Colors.orange : Colors.blue,
                ),
                title: Text(
                  product != null ? '📦 $product' : '💬 Conversation privée',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: Text(
                  lastMsg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openConversation(context, conv, myUserId);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? Colors.grey[800] : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.grey[500],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget pour une conversation individuelle
class ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String currentUserId;
  final VoidCallback onTap;
  final int? extraBadge; // Nombre de conversations en double avec ce user

  const ConversationTile({
    Key? key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
    this.extraBadge,
  }) : super(key: key);

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final messageDate = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(messageDate);

      if (difference.inMinutes < 1) {
        return 'À l\'instant';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h';
      } else if (difference.inDays == 1) {
        return 'Hier';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}j';
      } else {
        return '${messageDate.day}/${messageDate.month}/${messageDate.year}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherName = conversation['other_name'] ?? 'Utilisateur';
    final lastMessage = conversation['last_message'] ?? '';
    final unreadCount = conversation['unread_count'] ?? 0;
    final productName = conversation['product_name'];
    final isOnline = conversation['is_online'] == true;
    final timestamp = conversation['last_message_time'];
    final otherAvatar = conversation['other_avatar'];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: unreadCount > 0 
          ? theme.primaryColor.withOpacity(0.1) 
          : Colors.transparent, // transparent respects the scaffold background
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar avec statut en ligne
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null,
                    child: otherAvatar == null
                        ? Text(
                            otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  // Indicateur de statut en ligne
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? Colors.grey[900]! : Colors.white, width: 2),
                        ),
                      ),
                    ),
                  // Badge "+ X conversations" en double
                  if (extraBadge != null && extraBadge! > 1)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.grey[900]! : Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '+$extraBadge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              
              // Contenu de la conversation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom + Timestamp
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            otherName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: unreadCount > 0 ? Colors.blue : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Contexte produit (si existe)
                    Row(
                      children: [
                        if (productName != null) ...[
                          Icon(Icons.shopping_bag_outlined, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              productName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: TextStyle(
                                fontSize: 14,
                                color: unreadCount > 0 
                                    ? (isDark ? Colors.white : Colors.black87) 
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (productName != null && lastMessage.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lastMessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: unreadCount > 0 
                              ? (isDark ? Colors.white : Colors.black87) 
                              : (isDark ? Colors.grey[500] : Colors.grey[500]),
                          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    // Dernier message + Badge
                    if (productName == null && lastMessage.isEmpty) const SizedBox(height: 4),
                    Row(
                      children: [
                        const Spacer(),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _FilterChip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // On utilise un bleu foncé pour correspondre à la maquette si c'est sélectionné
    final activeColor = const Color(0xFF1565C0); 

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
