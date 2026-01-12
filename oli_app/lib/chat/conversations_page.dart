import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';
import '../core/user/user_provider.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    final String? myId = user?.id.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Discussions', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche (Optionnel : peut être liée à Firestore aussi)
          _buildSearchBar(),
          
          Expanded(
            child: myId == null 
              ? const Center(child: CircularProgressIndicator())
              : _buildFirestoreConversations(myId),
          ),
        ],
      ),
    );
  }

  /// Liste des conversations en temps réel via Firestore
  Widget _buildFirestoreConversations(String myId) {
    return StreamBuilder<QuerySnapshot>(
      // On écoute les conversations où l'utilisateur actuel est participant
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: myId)
          .orderBy('last_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Erreur : ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final convData = docs[index].data() as Map<String, dynamic>;
            final String conversationId = docs[index].id;
            
            // On récupère les infos de l'autre personne
            // Note: Dans Firestore, il est mieux de stocker un petit objet 'profiles' 
            // dans la conv pour éviter de refaire des requêtes.
            final otherId = (convData['participants'] as List).firstWhere((id) => id != myId);
            
            // Gestion du badge non lu
            final int unreadCount = convData['unread_count_$myId'] ?? 0;

            return ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue.shade100,
                child: Text(otherId[0].toUpperCase()),
              ),
              title: Text(
                "Utilisateur $otherId", // Idéalement, stockez le 'other_name' dans le doc
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                convData['last_message'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  color: unreadCount > 0 ? Colors.black : Colors.grey,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatFirestoreTime(convData['last_time'])),
                  if (unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text("$unreadCount", 
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                ],
              ),
              onTap: () => _openChat(
                otherId: otherId,
                conversationId: conversationId,
                otherName: "Utilisateur $otherId",
              ),
            );
          },
        );
      },
    );
  }

  void _openChat({required String otherId, String? conversationId, required String otherName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          myId: ref.read(userProvider).value!.id.toString(),
          otherId: otherId,
          otherName: otherName,
          conversationId: conversationId,
        ),
      ),
    );
  }

  // --- Helpers UI ---

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[300]),
          const Text("Aucune discussion pour le moment", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String _formatFirestoreTime(dynamic timestamp) {
    if (timestamp == null || timestamp is! Timestamp) return '';
    DateTime dt = timestamp.toDate();
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return "${dt.day}/${dt.month}";
  }
}