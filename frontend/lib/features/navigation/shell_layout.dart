import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/notifier/profile_notifier.dart';
import 'app_drawer.dart';

class ShellLayout extends StatefulWidget {
  final Widget child;
  const ShellLayout({super.key, required this.child});

  @override
  State<ShellLayout> createState() => _ShellLayoutState();
}

class _ShellLayoutState extends State<ShellLayout> {
  final ApiClient _apiClient = ApiClient();
  bool _isNotificationOpen = false;
  List<dynamic> _notifications = [];
  int _unreadNotificationCount = 2;
  int _unreadInboxCount = 1;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchNotifications();
  }

  Future<void> _loadUserProfile() async {
    try {
      final res = await _apiClient.dio.get('/auth/profile');
      ProfileNotifier.setProfile(res.data);
    } catch (e) {
      debugPrint('[ShellLayout] Failed to load user profile: $e');
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final res = await _apiClient.dio.get('/notifications');
      if (mounted) {
        final list = res.data as List<dynamic>? ?? [];
        final unreadCount = list.where((n) => n['isRead'] == false).length;
        setState(() {
          _notifications = list;
          _unreadNotificationCount = unreadCount > 0 ? unreadCount : 0;
        });
      }
    } catch (e) {
      debugPrint('[ShellLayout] Error fetching notifications: $e');
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return 'just now';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return 'just now';
    }
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/feed')) return 0;
    if (location.startsWith('/plans')) return 1;
    if (location.startsWith('/chat')) return 2;
    if (location.startsWith('/explore')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    setState(() {
      _isNotificationOpen = false;
    });

    if (index == 2) {
      // Clear Inbox unread badge upon tapping Inbox tab
      setState(() {
        _unreadInboxCount = 0;
      });
    }

    switch (index) {
      case 0:
        context.go('/feed');
        break;
      case 1:
        context.go('/plans');
        break;
      case 2:
        context.go('/chat');
        break;
      case 3:
        context.go('/explore');
        break;
    }
  }

  Widget _buildTabItem({
    required BuildContext context,
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    required int selectedIndex,
    int badgeCount = 0,
  }) {
    final isSelected = index == selectedIndex;
    final color = isSelected ? ThemeTokens.travelTeal : const Color(0xFF94A3B8);

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index, context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: color,
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCardItem({
    required IconData icon,
    required Color iconBg,
    required String titleText,
    required String actorName,
    required String actionMessage,
    required String timeText,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF0B1B2B), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0B1B2B)),
                      children: [
                        TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: ' $actionMessage'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeText,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);

    // Mock notification items matching user screenshot if database is empty
    final mockNotifications = [
      {
        'id': 'mock-1',
        'type': 'LIKE',
        'icon': Icons.favorite,
        'bg': const Color(0xFFFEF2F2),
        'actor': 'Elena Vance',
        'action': 'liked your Kyoto post',
        'time': '8 min ago',
      },
      {
        'id': 'mock-2',
        'type': 'JOIN_REQUEST',
        'icon': Icons.airplanemode_active,
        'bg': const Color(0xFFE6F4F2),
        'actor': 'Marco Polo',
        'action': 'requested to join Patagonia Trek',
        'time': '21 min ago',
      },
      {
        'id': 'mock-3',
        'type': 'COMMENT',
        'icon': Icons.chat_bubble_outline,
        'bg': const Color(0xFFFEF3C7),
        'actor': 'Sarah Jenkins',
        'action': 'commented: "Adding this to my list!"',
        'time': '3h ago',
      },
    ];

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF0B1B2B)),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: ThemeTokens.warmCoral,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Center(
                child: Text(
                  't',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'travelibe',
              style: TextStyle(
                color: Color(0xFF0B1B2B),
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Profile Avatar Icon Button
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: ProfileNotifier.currentUserProfile,
            builder: (context, profileData, _) {
              final profileObj = profileData?['profile'] as Map<String, dynamic>?;
              final avatarUrl = profileObj?['avatarUrl'] ?? profileData?['avatarUrl'] as String?;

              return GestureDetector(
                onTap: () {
                  context.push('/profile');
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF0F766E),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Notification Bell Icon with Red Counter Badge
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_none, color: Color(0xFF0B1B2B), size: 22),
                  onPressed: () {
                    setState(() {
                      _isNotificationOpen = !_isNotificationOpen;
                    });
                    if (_isNotificationOpen) {
                      _fetchNotifications();
                    }
                  },
                ),
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_unreadNotificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          // Main Body Screen
          GestureDetector(
            onTap: () {
              if (_isNotificationOpen) {
                setState(() => _isNotificationOpen = false);
              }
            },
            child: widget.child,
          ),

          // Inline Floating Notification Card Overlay (Matching User Screenshot!)
          if (_isNotificationOpen)
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B1B2B),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              try {
                                await _apiClient.dio.post('/notifications/read-all');
                                setState(() {
                                  _unreadNotificationCount = 0;
                                });
                                _fetchNotifications();
                              } catch (e) {
                                debugPrint('[ShellLayout] Mark all read failed: $e');
                              }
                            },
                            child: const Text(
                              'Mark all read',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // List Items (Real database notifications or Screenshot mock items)
                      if (_notifications.isNotEmpty)
                        ..._notifications.take(4).map((n) {
                          final type = n['type'] ?? 'LIKE';
                          final actor = n['actor']?['profile']?['displayName'] ?? 'User';
                          final title = n['title'] ?? 'interacted with your post';

                          IconData icon = Icons.favorite;
                          Color bg = const Color(0xFFFEF2F2);

                          if (type == 'COMMENT') {
                            icon = Icons.chat_bubble_outline;
                            bg = const Color(0xFFFEF3C7);
                          } else if (type == 'JOIN_REQUEST' || type == 'PLAN') {
                            icon = Icons.airplanemode_active;
                            bg = const Color(0xFFE6F4F2);
                          }

                          return _buildNotificationCardItem(
                            icon: icon,
                            iconBg: bg,
                            titleText: title,
                            actorName: actor,
                            actionMessage: title,
                            timeText: _timeAgo(n['createdAt']),
                            onTap: () async {
                              setState(() {
                                _isNotificationOpen = false;
                                if (_unreadNotificationCount > 0) _unreadNotificationCount--;
                              });
                              if (n['id'] != null) {
                                try {
                                  await _apiClient.dio.patch('/notifications/${n['id']}/read');
                                } catch (_) {}
                              }
                              if (type == 'JOIN_REQUEST' || type == 'PLAN') {
                                context.go('/plans');
                              } else {
                                context.go('/feed');
                              }
                            },
                          );
                        })
                      else
                        ...mockNotifications.map((m) {
                          final type = m['type'] as String;
                          return _buildNotificationCardItem(
                            icon: m['icon'] as IconData,
                            iconBg: m['bg'] as Color,
                            titleText: m['action'] as String,
                            actorName: m['actor'] as String,
                            actionMessage: m['action'] as String,
                            timeText: m['time'] as String,
                            onTap: () {
                              setState(() {
                                _isNotificationOpen = false;
                                if (_unreadNotificationCount > 0) _unreadNotificationCount--;
                              });
                              if (type == 'JOIN_REQUEST' || type == 'PLAN') {
                                context.go('/plans');
                              } else {
                                context.go('/feed');
                              }
                            },
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 16,
        shadowColor: Colors.black.withOpacity(0.3),
        padding: EdgeInsets.zero,
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabItem(
              context: context,
              index: 0,
              activeIcon: Icons.home,
              inactiveIcon: Icons.home_outlined,
              label: 'Home',
              selectedIndex: selectedIndex,
            ),
            _buildTabItem(
              context: context,
              index: 1,
              activeIcon: Icons.map,
              inactiveIcon: Icons.map_outlined,
              label: 'Plans',
              selectedIndex: selectedIndex,
            ),
            _buildTabItem(
              context: context,
              index: 2,
              activeIcon: Icons.chat_bubble,
              inactiveIcon: Icons.chat_bubble_outline,
              label: 'Inbox',
              selectedIndex: selectedIndex,
              badgeCount: _unreadInboxCount,
            ),
            _buildTabItem(
              context: context,
              index: 3,
              activeIcon: Icons.explore,
              inactiveIcon: Icons.explore_outlined,
              label: 'Explore',
              selectedIndex: selectedIndex,
            ),
          ],
        ),
      ),
    );
  }
}
