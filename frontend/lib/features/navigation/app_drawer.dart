import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/notifier/profile_notifier.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final ApiClient _apiClient = ApiClient();
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await _apiClient.dio.get('/auth/profile');
      ProfileNotifier.setProfile(response.data);
    } catch (e) {
      debugPrint('Failed to fetch profile for drawer: $e');
    }
  }

  Future<void> _logout() async {
    await _apiClient.clearToken();
    if (mounted) {
      GoRouter.of(context).go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: ProfileNotifier.currentUserProfile,
      builder: (context, profileData, _) {
        final userProfile = profileData?['profile'] as Map<String, dynamic>?;
        final name = userProfile?['displayName'] ?? profileData?['displayName'] ?? 'Traveler User';
        final email = profileData?['email'] ?? 'user@travelibe.com';
        final avatar = userProfile?['avatarUrl'] ?? profileData?['avatarUrl'] as String?;

        return Drawer(
          child: Column(
            children: [
              // Drawer Header with User Info & Avatar (Clickable to open ProfileScreen)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/profile');
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 24,
                    bottom: 24,
                    left: 20,
                    right: 20,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F766E),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white,
                        backgroundImage: avatar != null && avatar.isNotEmpty
                            ? NetworkImage(avatar)
                            : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Drawer Menu Options
              ListTile(
                leading: const Icon(Icons.brightness_6, color: Color(0xFF0F766E)),
                title: const Text('Dark Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                trailing: Switch(
                  value: _isDarkMode,
                  activeColor: const Color(0xFF0F766E),
                  onChanged: (val) {
                    setState(() {
                      _isDarkMode = val;
                    });
                  },
                ),
              ),
              const Divider(),

              const Spacer(),
              const Divider(height: 1),

              // Logout Button
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Log Out',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
