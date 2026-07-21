import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.dio.get('/notifications');
      setState(() {
        _notifications = res.data;
        _isLoading = false;
      });
      // Mark as read after fetching
      _apiClient.dio.post('/notifications/read-all');
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('[NotificationsScreen] Error fetching notifications: $e');
    }
  }

  String _getTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'LIKE':
      case 'STORY_LIKE':
        return Icons.favorite;
      case 'COMMENT':
        return Icons.chat_bubble_outline;
      case 'SHARE':
        return Icons.repeat;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'LIKE':
      case 'STORY_LIKE':
        return Colors.redAccent;
      case 'COMMENT':
        return const Color(0xFF0F766E);
      case 'SHARE':
        return Colors.blueAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0B1B2B)),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Color(0xFF0B1B2B), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Color(0xFF0F766E)),
            tooltip: 'Mark all as read',
            onPressed: () async {
              await _apiClient.dio.post('/notifications/read-all');
              _fetchNotifications();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
            : _notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No notifications yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'When people react or comment on your posts, you will see it here.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (c, i) => const Divider(height: 1, indent: 72, color: Color(0xFFECECE8)),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final actor = notif['actor'];
                      final profile = actor != null ? actor['profile'] : null;
                      final name = profile != null ? profile['displayName'] : 'User';
                      final avatar = profile != null ? profile['avatarUrl'] : null;
                      final type = notif['type'] ?? 'LIKE';

                      return Container(
                        color: notif['isRead'] == false ? const Color(0xFFF0FDF4) : Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.teal.shade100,
                                backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                                    ? NetworkImage(avatar)
                                    : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: _getNotificationColor(type),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: Icon(_getNotificationIcon(type), color: Colors.white, size: 10),
                                ),
                              ),
                            ],
                          ),
                          title: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Color(0xFF0B1B2B), fontSize: 14),
                              children: [
                                TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: ' ${notif['message']}'),
                              ],
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              _getTimeAgo(notif['createdAt']),
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
