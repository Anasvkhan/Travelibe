import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/notifier/profile_notifier.dart';

class ProfileScreen extends StatefulWidget {
  final String? targetUserId;
  const ProfileScreen({super.key, this.targetUserId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  Map<String, dynamic> _profile = {};
  List<dynamic> _userPosts = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (widget.targetUserId == null) {
        // Load logged in user's profile
        final response = await _apiClient.dio.get('/auth/profile');
        _profile = response.data;

        // Fetch user's posts
        try {
          final postsRes = await _apiClient.dio.get('/feed/posts/user/${_profile['userId']}');
          _userPosts = postsRes.data;
        } catch (e) {
          debugPrint('[ProfileScreen] Error loading user posts: $e');
        }
      } else {
        // Fetch target user's posts & profile info
        final postsRes = await _apiClient.dio.get('/feed/posts/user/${widget.targetUserId}');
        _userPosts = postsRes.data;
        if (_userPosts.isNotEmpty && _userPosts[0]['user'] != null && _userPosts[0]['user']['profile'] != null) {
          _profile = Map<String, dynamic>.from(_userPosts[0]['user']['profile']);
          _profile['userId'] = widget.targetUserId;
        } else {
          _profile = {
            'displayName': 'Traveler',
            'handle': 'user',
            'homeLocation': 'World Citizen',
            'aboutMe': 'Passionate explorer on Travelibe.',
          };
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Image Upload helper (System Gallery Picker)
  Future<void> _uploadImage(String fieldName) async {
    if (widget.targetUserId != null) return; // Only owner can upload

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading image...'), duration: Duration(seconds: 1)),
    );

    try {
      final bytes = await image.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: image.name),
      });

      final response = await _apiClient.dio.post('/upload/media', data: formData);
      if (response.data['success'] == true) {
        final mediaUrl = response.data['mediaUrl'];
        
        final updatedData = Map<String, dynamic>.from(_profile);
        updatedData[fieldName] = mediaUrl;

        await _apiClient.dio.put('/auth/profile', data: updatedData);
        setState(() {
          _profile[fieldName] = mediaUrl;
        });

        if (fieldName == 'avatarUrl') {
          ProfileNotifier.updateAvatar(mediaUrl);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Show Edit Profile Overlay Sheet
  void _showEditProfileOverlay() {
    final nameController = TextEditingController(text: _profile['displayName'] ?? '');
    final handleController = TextEditingController(text: _profile['handle'] ?? '');
    final locationController = TextEditingController(text: _profile['homeLocation'] ?? '');
    final aboutController = TextEditingController(text: _profile['aboutMe'] ?? 'Adventure seeker, slow-travel believer.');
    final interestsController = TextEditingController(
      text: (_profile['travelInterests'] != null)
          ? (_profile['travelInterests'] as List<dynamic>).join(', ')
          : 'Road trips, Photography, Food trails, Mountains',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit profile',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: handleController,
                    decoration: const InputDecoration(labelText: 'Handle', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: aboutController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'About me', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: interestsController,
                    decoration: const InputDecoration(labelText: 'Interests (comma separated)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final interestsList = interestsController.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();

                      final payload = {
                        'displayName': nameController.text.trim(),
                        'handle': handleController.text.trim(),
                        'homeLocation': locationController.text.trim(),
                        'avatarUrl': _profile['avatarUrl'],
                        'backgroundUrl': _profile['backgroundUrl'],
                        'aboutMe': aboutController.text.trim(),
                        'travelInterests': interestsList,
                      };

                      try {
                        await _apiClient.dio.put('/auth/profile', data: payload);
                        setState(() {
                          _profile['displayName'] = nameController.text.trim();
                          _profile['handle'] = handleController.text.trim();
                          _profile['homeLocation'] = locationController.text.trim();
                          _profile['aboutMe'] = aboutController.text.trim();
                          _profile['travelInterests'] = interestsList;
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Changes saved successfully!'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (err) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Save failed: $err'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text('Save changes', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0F766E))),
      );
    }

    final avatar = _profile['avatarUrl'] as String?;
    final cover = _profile['backgroundUrl'] as String?;
    final name = _profile['displayName'] ?? 'Traveler';
    final handle = _profile['handle'] ?? 'username';
    final location = _profile['homeLocation'] ?? 'Islamabad, Pakistan';
    final about = _profile['aboutMe'] ?? 'Adventure seeker, slow-travel believer and unapologetic window-seat person.';
    final List<dynamic> interests = _profile['travelInterests'] as List<dynamic>? ?? ['Road trips', 'Photography', 'Food trails', 'Mountains'];
    final isMe = widget.targetUserId == null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: Navigator.canPop(context)
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0B1B2B)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(name, style: const TextStyle(color: Color(0xFF0B1B2B), fontWeight: FontWeight.bold)),
            )
          : null,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner (Cover Photo) + Circular Avatar Stack
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover photo
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    image: cover != null && cover.isNotEmpty
                        ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover)
                        : const DecorationImage(
                            image: NetworkImage('https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&q=80&w=1000'),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: isMe
                      ? Stack(
                          children: [
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: CircleAvatar(
                                backgroundColor: Colors.black.withOpacity(0.5),
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                  onPressed: () => _uploadImage('backgroundUrl'),
                                ),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
                // Circular Avatar overlapping cover photo
                Positioned(
                  bottom: -50,
                  left: 24,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => isMe ? _uploadImage('avatarUrl') : null,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade100,
                            backgroundImage: avatar != null && avatar.isNotEmpty
                                ? NetworkImage(avatar)
                                : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                          ),
                        ),
                      ),
                      if (isMe)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            backgroundColor: const Color(0xFF0F766E),
                            radius: 16,
                            child: IconButton(
                              icon: const Icon(Icons.edit, size: 12, color: Colors.white),
                              onPressed: () => _uploadImage('avatarUrl'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),

            // Profile info details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@$handle · $location',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      if (isMe)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0B1B2B),
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showEditProfileOverlay,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            try {
                              await _apiClient.dio.post('/chat/connections/request', data: {
                                'receiverId': widget.targetUserId,
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Connection request / Message initiated!'), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          icon: const Icon(Icons.person_add, size: 16),
                          label: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    about,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF4A4A4A), height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  // Interests tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: interests.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag.toString(),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Tabs selection: Posts, Trips, Saved
                  DefaultTabController(
                    length: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TabBar(
                          labelColor: const Color(0xFF0F766E),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: const Color(0xFF0F766E),
                          tabs: [
                            Tab(text: 'Posts (${_userPosts.length})'),
                            const Tab(text: 'Trips (0)'),
                            const Tab(text: 'Saved (0)'),
                          ],
                        ),
                        SizedBox(
                          height: 350,
                          child: TabBarView(
                            children: [
                              // Posts Tab
                              _userPosts.isEmpty
                                  ? const Center(child: Text('No posts published yet.', style: TextStyle(color: Colors.grey)))
                                  : GridView.builder(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 4,
                                        mainAxisSpacing: 4,
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      itemCount: _userPosts.length,
                                      itemBuilder: (context, idx) {
                                        final post = _userPosts[idx];
                                        final media = post['media'] as List<dynamic>? ?? [];
                                        final String? imgUrl = media.isNotEmpty ? media[0]['mediaUrl'] : null;

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                            image: imgUrl != null
                                                ? DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover)
                                                : null,
                                          ),
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.all(4),
                                          child: imgUrl == null
                                              ? Text(
                                                  post['text'] ?? '',
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                                                  textAlign: TextAlign.center,
                                                )
                                              : null,
                                        );
                                      },
                                    ),
                              // Trips Tab
                              const Center(child: Text('No active trips planned yet.', style: TextStyle(color: Colors.grey))),
                              // Saved Tab
                              const Center(child: Text('No saved items yet.', style: TextStyle(color: Colors.grey))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0B1B2B))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
