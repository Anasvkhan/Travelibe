import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/api/api_client.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final ApiClient _apiClient = ApiClient();
  int _activeTab = 0; // 0: Messages, 1: Requests

  List<Map<String, dynamic>> _activeChats = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _appUsers = [];
  String? _myUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userRes = await _apiClient.dio.get('/auth/profile');
      _myUserId = userRes.data['id'];

      final convRes = await _apiClient.dio.get('/chat/conversations');
      final connRes = await _apiClient.dio.get('/chat/connections');
      final usersRes = await _apiClient.dio.get('/chat/users/search');

      if (mounted) {
        setState(() {
          _activeChats = (convRes.data as List).map((conv) {
             final members = conv['members'] as List;
             final member = members.firstWhere((m) => m['userId'] != _myUserId, orElse: () => members[0]);
             final user = member['user'];
             final msg = (conv['messages'] != null && conv['messages'].isNotEmpty) ? conv['messages'][0]['text'] : 'No messages yet';
             final time = (conv['messages'] != null && conv['messages'].isNotEmpty) ? conv['messages'][0]['createdAt'] : conv['updatedAt'];
             
             return {
                'id': conv['id'],
                'targetUserId': user['id'],
                'name': user['profile']['displayName'] ?? 'Traveler',
                'message': msg,
                'time': _formatTime(time),
                'url': user['profile']['avatarUrl'] ?? 'https://picsum.photos/100',
                'unreadCount': 0, // Not implemented on backend yet
                'isPending': false, // UI logic for pending sent messages
                'isOnline': member['isOnline'] ?? false,
             };
          }).toList();

          final pending = (connRes.data as List).where((conn) => conn['status'] == 'PENDING' && conn['receiverId'] == _myUserId).toList();
          _pendingRequests = pending.map((conn) {
             final reqUser = conn['requester'];
             return {
                'id': conn['id'],
                'name': reqUser['profile']['displayName'] ?? 'Traveler',
                'detail': reqUser['profile']['bio'] ?? 'Wants to connect',
                'url': reqUser['profile']['avatarUrl'] ?? 'https://picsum.photos/100',
                'message': 'Sent a connection request',
                'time': 'Recent',
             };
          }).toList();

          _appUsers = (usersRes.data as List).map((u) {
             return {
                'id': u['id'],
                'name': u['profile']['displayName'] ?? 'Traveler',
                'detail': u['profile']['bio'] ?? 'Traveler',
                'url': u['profile']['avatarUrl'] ?? 'https://picsum.photos/100',
             };
          }).toList();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('[InboxScreen] Error loading data: $e');
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr).toLocal();
      return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  // Accept Connection Request
  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      await _apiClient.dio.post('/chat/connections/${request['id']}/accept');
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection accepted with ${request['name']}! Message moved to Inbox.'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error accepting request: $e');
    }
  }

  // Reject / Remove Connection Request
  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    try {
      await _apiClient.dio.post('/chat/connections/${request['id']}/reject');
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request from ${request['name']} was rejected. Notification sent to sender.'),
            backgroundColor: ThemeTokens.warmCoral,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error rejecting request: $e');
    }
  }

  // Compose / Start new conversation
  void _showSearchComposeDialog() {
    String searchQuery = '';
    List<Map<String, dynamic>> filteredUsers = List.from(_appUsers);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'New Conversation',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextFormField(
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                            filteredUsers = _appUsers
                                .where((user) => user['name']
                                    .toLowerCase()
                                    .contains(searchQuery.toLowerCase()))
                                .toList();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search traveler by name...',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'REGISTERED TRAVELIBERS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundImage: NetworkImage(user['url']),
                            ),
                            title: Text(
                              user['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
                            ),
                            subtitle: Text(user['detail']),
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE6F4F2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send, color: Color(0xFF0F766E), size: 16),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _initiateChatWithUser(user);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Initiate Chat
  Future<void> _initiateChatWithUser(Map<String, dynamic> user) async {
    final existingChat = _activeChats.where((chat) => chat['targetUserId'] == user['id']).firstOrNull ?? _activeChats.where((chat) => chat['name'] == user['name']).firstOrNull;
    if (existingChat != null) {
      context.push('/chat/detail', extra: {'conversationId': existingChat['id']});
      return;
    }

    try {
      final res = await _apiClient.dio.post('/chat/conversations', data: {'targetUserId': user['id']});
      _loadData();
      if (mounted) {
        context.push('/chat/detail', extra: {'conversationId': res.data['id']});
      }
    } catch (e) {
      debugPrint('Error creating conversation: $e');
    }
  }

  // Delete Conversation Method
  void _confirmDeleteChat(Map<String, dynamic> chat) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete conversation?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to delete your chat with ${chat['name']}? All messages in this conversation will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _apiClient.dio.delete('/chat/conversations/${chat['id']}');
                } catch (e) {
                  debugPrint('[InboxScreen] Error deleting conversation: $e');
                }
                setState(() {
                  _activeChats.removeWhere((c) => c['id'] == chat['id']);
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Conversation with ${chat['name']} deleted.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCircleUser({required String name, required String url, bool isOnline = true}) {
    return Padding(
      padding: const EdgeInsets.only(right: 20.0),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(url),
              ),
              if (isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    return InkWell(
      onTap: () => context.push('/chat/detail', extra: {'conversationId': chat['id']}),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: NetworkImage(chat['url']),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        chat['name'],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B1B2B),
                        ),
                      ),
                      if (chat['isPending'] == true) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PENDING',
                            style: TextStyle(color: Colors.orange.shade800, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat['message'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: chat['unreadCount'] > 0 ? const Color(0xFF0B1B2B) : Colors.grey.shade500,
                      fontWeight: chat['unreadCount'] > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat['time'],
                  style: TextStyle(
                    fontSize: 11,
                    color: chat['unreadCount'] > 0 ? const Color(0xFF0F766E) : Colors.grey.shade400,
                    fontWeight: chat['unreadCount'] > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 6),
                if (chat['unreadCount'] > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F766E),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      chat['unreadCount'].toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.grey.shade400, size: 20),
              onPressed: () => _confirmDeleteChat(chat),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> request) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: NetworkImage(request['url']),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request['name'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B1B2B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  request['detail'],
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      ),
                      onPressed: () => _acceptRequest(request),
                      child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF0B1B2B),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      ),
                      onPressed: () => _rejectRequest(request),
                      child: const Text('Remove', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              'YOUR CIRCLE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Inbox',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B1B2B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Color(0xFF0B1B2B), size: 28),
                  onPressed: _showSearchComposeDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab switcher
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _activeTab = 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Messages',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 0 ? const Color(0xFF0F766E) : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 60,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _activeTab == 0 ? const Color(0xFF0F766E) : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                GestureDetector(
                  onTap: () => setState(() => _activeTab = 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Requests',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _activeTab == 1 ? const Color(0xFF0F766E) : Colors.grey.shade500,
                            ),
                          ),
                          if (_pendingRequests.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ThemeTokens.warmCoral.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _pendingRequests.length.toString(),
                                style: const TextStyle(
                                  color: ThemeTokens.warmCoral,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 60,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _activeTab == 1 ? const Color(0xFF0F766E) : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 1, color: Color(0xFFECECE8)),
            const SizedBox(height: 16),

            // Search messages field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Search messages',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Active users online row
            if (_activeTab == 0 && _activeChats.isNotEmpty) ...[
              SizedBox(
                height: 84,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _activeChats.length,
                  itemBuilder: (context, index) {
                    final chat = _activeChats[index];
                    return _buildCircleUser(
                      name: chat['name'].split(' ')[0],
                      url: chat['url'],
                      isOnline: chat['isOnline'] ?? false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFECECE8)),
            ],

            // Content List depending on active tab
            Expanded(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
                  : _activeTab == 0
                      ? _activeChats.isEmpty 
                          ? const Center(child: Text('No messages yet', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: _activeChats.length,
                              itemBuilder: (context, index) {
                                return _buildChatItem(_activeChats[index]);
                              },
                            )
                      : _pendingRequests.isEmpty
                          ? const Center(child: Text('No pending requests', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: _pendingRequests.length,
                              itemBuilder: (context, index) {
                                return _buildRequestItem(_pendingRequests[index]);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
