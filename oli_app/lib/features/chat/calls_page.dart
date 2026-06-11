import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/call_history_provider.dart';
import '../../core/user/user_provider.dart';
import 'call_screen.dart';

class CallsPage extends ConsumerStatefulWidget {
  const CallsPage({super.key});

  @override
  ConsumerState<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends ConsumerState<CallsPage> {
  @override
  Widget build(BuildContext context) {
    final callsAsync = ref.watch(callHistoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(userProvider).value;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Journal d\'appels'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: callsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Erreur: $err")),
        data: (calls) {
          if (calls.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_missed, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "Aucun appel",
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(callHistoryProvider.notifier).fetchCallHistory(),
            child: ListView.separated(
              itemCount: calls.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
              itemBuilder: (context, index) {
                final call = calls[index];
                return _buildCallTile(call, user?.id.toString());
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCallTile(Map<String, dynamic> call, String? currentUserId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isCaller = call['caller_id']?.toString() == currentUserId;
    final String status = call['status'] ?? 'missed';
    final String type = call['call_type'] ?? 'audio';
    
    IconData statusIcon;
    Color statusColor;

    if (status == 'missed') {
      statusIcon = Icons.phone_missed;
      statusColor = Colors.red;
    } else if (isCaller) {
      statusIcon = Icons.call_made;
      statusColor = Colors.blue;
    } else {
      statusIcon = Icons.call_received;
      statusColor = Colors.green;
    }

    final String otherName = call['other_name'] ?? 'Inconnu';
    final String? otherAvatar = call['other_avatar'];
    final String? otherId = call['other_id']?.toString() ?? (isCaller ? call['receiver_id']?.toString() : call['caller_id']?.toString());
    
    // Format duration
    final int duration = call['duration_seconds'] ?? 0;
    String durationStr = '';
    if (duration > 0 && status == 'answered') {
      final int m = duration ~/ 60;
      final int s = duration % 60;
      durationStr = m > 0 ? '$m min $s s' : '$s s';
    } else {
      if (status == 'missed') durationStr = 'Manqué';
      else if (status == 'rejected') durationStr = 'Refusé';
      else if (status == 'cancelled') durationStr = 'Annulé';
    }

    // Format time
    String timeStr = '';
    if (call['created_at'] != null) {
      try {
        final date = DateTime.parse(call['created_at']);
        final now = DateTime.now();
        if (date.day == now.day && date.month == now.month && date.year == now.year) {
          timeStr = "Aujourd'hui, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
        } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
          timeStr = "Hier, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
        } else {
          timeStr = "${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
        }
      } catch (_) {}
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
        backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null,
        child: otherAvatar == null
            ? Text(
                otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              )
            : null,
      ),
      title: Text(
        otherName,
        style: TextStyle(
          color: status == 'missed' ? Colors.red : (isDark ? Colors.white : Colors.black),
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              "$timeStr \u2022 $durationStr",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          type == 'video' ? Icons.videocam : Icons.phone,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () {
          if (otherId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CallScreen(
                  isIncoming: false,
                  otherName: otherName,
                  otherAvatarUrl: otherAvatar ?? '',
                  otherId: otherId,
                  isVideoCall: type == 'video',
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
