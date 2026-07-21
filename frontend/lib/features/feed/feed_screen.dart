import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/notifier/profile_notifier.dart';
import '../../core/api/api_client.dart';
import '../profile/profile_screen.dart';
import 'story_viewer_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _ExploreTabFilter {
  static const int forYou = 0;
  static const int following = 1;
  static const int trending = 2;
}

class _FeedScreenState extends State<FeedScreen> {
  final ApiClient _apiClient = ApiClient();
  int _activeTabIndex = _ExploreTabFilter.forYou;

  bool _loadingFeed = false;
  bool _loadingStories = false;

  List<dynamic> _posts = [];
  List<dynamic> _stories = [];

  Map<String, dynamic>? _currentUserProfile;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _currentUserProfile = ProfileNotifier.currentUserProfile.value;
    _loadCachedFeed();
    _loadCurrentUser();
    _fetchStories();
    _fetchFeed();

    // Auto-refresh feed silently every 45s like Instagram
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _silentRefreshFeed();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_feed_posts');
      if (raw != null && raw.isNotEmpty && _posts.isEmpty) {
        final cached = jsonDecode(raw) as List<dynamic>;
        setState(() {
          _posts = cached;
          _loadingFeed = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _silentRefreshFeed() async {
    try {
      String filterParam = 'for_you';
      if (_activeTabIndex == _ExploreTabFilter.following) filterParam = 'following';
      if (_activeTabIndex == _ExploreTabFilter.trending) filterParam = 'trending';

      final res = await _apiClient.dio.get('/feed/posts', queryParameters: {
        'filter': filterParam,
      });

      if (mounted) {
        setState(() {
          _posts = res.data;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_feed_posts', jsonEncode(res.data));
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentUser() async {
    try {
      final res = await _apiClient.dio.get('/auth/profile');
      ProfileNotifier.setProfile(res.data);
      if (mounted) {
        setState(() {
          _currentUserProfile = res.data;
        });
      }
    } catch (e) {
      debugPrint('[FeedScreen] Failed to load current user profile: $e');
    }
  }

  Future<void> _fetchStories() async {
    setState(() {
      _loadingStories = true;
    });
    try {
      final res = await _apiClient.dio.get('/feed/stories');
      setState(() {
        _stories = res.data;
        _loadingStories = false;
      });
    } catch (e) {
      setState(() {
        _loadingStories = false;
      });
      debugPrint('[FeedScreen] Error fetching stories: $e');
    }
  }

  Future<void> _fetchFeed() async {
    setState(() {
      _loadingFeed = true;
    });
    try {
      String filterParam = 'for_you';
      if (_activeTabIndex == _ExploreTabFilter.following) filterParam = 'following';
      if (_activeTabIndex == _ExploreTabFilter.trending) filterParam = 'trending';

      final res = await _apiClient.dio.get('/feed/posts', queryParameters: {
        'filter': filterParam,
      });

      setState(() {
        _posts = res.data;
        _loadingFeed = false;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_feed_posts', jsonEncode(res.data));
    } catch (e) {
      setState(() {
        _loadingFeed = false;
      });
      debugPrint('[FeedScreen] Error fetching feed: $e');
    }
  }

  // Add / Create Story with Instagram Creator Modal
  Future<void> _addStory() async {
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (media == null) return;

    final textOverlayController = TextEditingController();
    Color overlayTextColor = Colors.white;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Background Image Preview
                    Positioned.fill(
                      child: FutureBuilder<List<int>>(
                        future: media.readAsBytes(),
                        builder: (c, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
                          }
                          return Image.memory(snapshot.data! as dynamic, fit: BoxFit.cover);
                        },
                      ),
                    ),

                    // Top Bar Header
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          const Text(
                            'New Story',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.text_fields, color: Colors.white, size: 28),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),

                    // Floating Text Overlay Input
                    Positioned(
                      left: 24,
                      right: 24,
                      top: 120,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: textOverlayController,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: overlayTextColor, fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: 'Type text...',
                            hintStyle: TextStyle(color: Colors.white54, fontSize: 18),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),

                    // Color Picker Row
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Colors.white, const Color(0xFFE15F41), const Color(0xFF0F766E), Colors.yellow, Colors.pinkAccent].map((color) {
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                overlayTextColor = color;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Share Story Bottom Button
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sharing to your story...'), duration: Duration(seconds: 1)),
                          );

                          try {
                            final bytes = await media.readAsBytes();
                            final formData = FormData.fromMap({
                              'file': MultipartFile.fromBytes(bytes, filename: media.name),
                            });

                            final uploadRes = await _apiClient.dio.post('/upload/media', data: formData);
                            if (uploadRes.data['success'] == true) {
                              final mediaUrl = uploadRes.data['mediaUrl'];
                              await _apiClient.dio.post('/feed/stories', data: {
                                'mediaUrl': mediaUrl,
                                'mediaType': 'image',
                              });

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Story posted successfully!'), backgroundColor: Colors.green),
                                );
                                _fetchStories();
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to post story: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Your Story', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // Create Post Modal
  void _openCreatePostModal() {
    final textController = TextEditingController();
    final locationController = TextEditingController();
    List<String> uploadedMediaUrls = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                            'Create Post',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Post caption text field
                      TextField(
                        controller: textController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Share a travel moment, thoughts, or experience...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Location tag input
                      TextField(
                        controller: locationController,
                        decoration: InputDecoration(
                          hintText: 'Add Location Tag (e.g. Amalfi, Italy)',
                          prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF0F766E)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Media Previews
                      if (uploadedMediaUrls.isNotEmpty) ...[
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: uploadedMediaUrls.length,
                            separatorBuilder: (c, i) => const SizedBox(width: 8),
                            itemBuilder: (c, idx) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  uploadedMediaUrls[idx],
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final images = await picker.pickMultiImage(imageQuality: 75, limit: 15 - uploadedMediaUrls.length);
                              if (images.isEmpty) return;

                              for (var image in images) {
                                if (uploadedMediaUrls.length >= 15) break;
                                final bytes = await image.readAsBytes();
                                final formData = FormData.fromMap({
                                  'file': MultipartFile.fromBytes(bytes, filename: image.name),
                                });

                                try {
                                  final res = await _apiClient.dio.post('/upload/media', data: formData);
                                  if (res.data['success'] == true) {
                                    setModalState(() {
                                      uploadedMediaUrls.add(res.data['mediaUrl']);
                                    });
                                  }
                                } catch (e) {
                                  debugPrint('Upload error: $e');
                                }
                              }
                            },
                            icon: const Icon(Icons.image_search, color: Color(0xFF0F766E)),
                            label: const Text('Add Images (Max 15)', style: TextStyle(color: Color(0xFF0F766E))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0F766E)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          final text = textController.text.trim();
                          if (text.isEmpty && uploadedMediaUrls.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please write text or attach an image.')),
                            );
                            return;
                          }

                          try {
                            final mediaPayload = uploadedMediaUrls.map((url) => {
                              'mediaUrl': url,
                              'mediaType': 'image',
                            }).toList();

                            await _apiClient.dio.post('/feed/posts', data: {
                              'text': text,
                              'location': locationController.text.trim(),
                              'media': mediaPayload,
                            });

                            if (mounted) {
                              Navigator.pop(context);
                              _fetchFeed();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Post published!'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to publish post: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                        child: const Text('Publish Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }



  // Open Comments Bottom Sheet
  void _openCommentsSheet(dynamic post) {
    final commentController = TextEditingController();
    List<dynamic> comments = post['comments'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setCommentState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Title Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comments (${comments.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Comments List
                  Expanded(
                    child: comments.isEmpty
                        ? const Center(child: Text('No comments yet. Be the first to comment!', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: comments.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 16),
                            itemBuilder: (c, idx) {
                              final comment = comments[idx];
                              final user = comment['user'];
                              final profile = user != null ? user['profile'] : null;
                              final avatar = profile != null ? profile['avatarUrl'] : null;
                              final name = profile != null ? profile['displayName'] : 'User';
                              bool commentLiked = comment['isLikedByMe'] ?? false;
                              int commentLikes = comment['likeCount'] ?? 0;

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: comment['userId'])),
                                      );
                                    },
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundImage: (avatar != null && avatar.isNotEmpty)
                                          ? NetworkImage(avatar)
                                          : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(comment['text'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      commentLiked ? Icons.favorite : Icons.favorite_border,
                                      color: commentLiked ? Colors.red : Colors.grey,
                                      size: 16,
                                    ),
                                    onPressed: () async {
                                      try {
                                        final res = await _apiClient.dio.post('/feed/comments/${comment['id']}/react');
                                        setCommentState(() {
                                          comment['isLikedByMe'] = res.data['liked'];
                                          comment['likeCount'] = res.data['count'];
                                        });
                                      } catch (e) {
                                        debugPrint('Comment like error: $e');
                                      }
                                    },
                                  ),
                                  if (commentLikes > 0)
                                    Text('$commentLikes', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              );
                            },
                          ),
                  ),

                  // Comment Input Bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF0F766E)),
                          onPressed: () async {
                            final text = commentController.text.trim();
                            if (text.isEmpty) return;

                            try {
                              final res = await _apiClient.dio.post('/feed/posts/${post['id']}/comment', data: {
                                'text': text,
                              });
                              commentController.clear();
                              setCommentState(() {
                                comments.add(res.data);
                              });
                              _fetchFeed();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to comment: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Post Options Sheet (Edit / Delete)
  void _showPostOptionsSheet(dynamic post) {
    final myUserId = _currentUserProfile?['userId'];
    final postUserId = post['userId'];
    final isMyPost = (myUserId != null && myUserId == postUserId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMyPost) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Color(0xFF0F766E)),
                  title: const Text('Edit post', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openEditPostModal(post);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete post', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeletePost(post);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.report_outlined, color: Colors.orange),
                  title: const Text('Report post'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted.')),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openEditPostModal(dynamic post) {
    final textController = TextEditingController(text: post['text'] ?? '');
    final locationController = TextEditingController(text: post['location'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit post', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(labelText: 'Caption', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location Tag', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
              onPressed: () async {
                final newText = textController.text.trim();
                final newLoc = locationController.text.trim();

                try {
                  final res = await _apiClient.dio.put('/feed/posts/${post['id']}', data: {
                    'text': newText,
                    'location': newLoc,
                  });

                  setState(() {
                    post['text'] = res.data['text'];
                    post['location'] = res.data['location'];
                  });

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post updated successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Edit failed: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Save changes'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeletePost(dynamic post) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete post?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await _apiClient.dio.delete('/feed/posts/${post['id']}');
                  setState(() {
                    _posts.removeWhere((p) => p['id'] == post['id']);
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post deleted successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Yes, Delete'),
            ),
          ],
        );
      },
    );
  }

  // Open Reshare / Share Modal
  void _openShareModal(dynamic post) {
    final shareTextController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reshare Post', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: shareTextController,
                decoration: const InputDecoration(
                  hintText: 'Say something about this post...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  post['text'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await _apiClient.dio.post('/feed/posts/${post['id']}/share', data: {
                    'text': shareTextController.text.trim(),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    _fetchFeed();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reshared to your feed!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Share Now'),
            ),
          ],
        );
      },
    );
  }

  // Format Likes text Instagram style
  Widget _buildInstagramLikesRow(dynamic post) {
    final reactions = post['reactions'] as List<dynamic>? ?? [];
    final likeCount = post['likeCount'] ?? reactions.length;

    String likesText = '';
    if (reactions.isEmpty) {
      likesText = 'Be the first to like this';
    } else if (reactions.length == 1) {
      final name = reactions[0]['user']?['profile']?['displayName'] ?? 'User';
      likesText = 'Liked by $name';
    } else if (reactions.length == 2) {
      final name1 = reactions[0]['user']?['profile']?['displayName'] ?? 'User';
      final name2 = reactions[1]['user']?['profile']?['displayName'] ?? 'User';
      likesText = 'Liked by $name1 and $name2';
    } else {
      final name1 = reactions[0]['user']?['profile']?['displayName'] ?? 'User';
      final name2 = reactions[1]['user']?['profile']?['displayName'] ?? 'User';
      final others = likeCount - 2 > 0 ? likeCount - 2 : reactions.length - 2;
      likesText = 'Liked by $name1, $name2 and $others others';
    }

    return GestureDetector(
      onTap: () => _openLikedByUsersSheet(post),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Text(
          likesText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0B1B2B),
          ),
        ),
      ),
    );
  }

  // Open Instagram-style Likes Bottom Sheet Modal
  void _openLikedByUsersSheet(dynamic post) {
    final reactions = post['reactions'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Likes (${reactions.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B1B2B),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: reactions.isEmpty
                        ? const Center(child: Text('No likes yet', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: reactions.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 12),
                            itemBuilder: (c, i) {
                              final react = reactions[i];
                              final u = react['user'];
                              final prof = u != null ? u['profile'] : null;
                              final name = prof != null ? prof['displayName'] : 'Traveler';
                              final handle = prof != null ? prof['handle'] : 'user';
                              final avatar = prof != null ? prof['avatarUrl'] : null;
                              final targetUserId = react['userId'] ?? (u != null ? u['id'] : '');

                              return Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: targetUserId)),
                                      );
                                    },
                                    child: CircleAvatar(
                                      radius: 22,
                                      backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                                          ? NetworkImage(avatar)
                                          : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: targetUserId)),
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text('@$handle', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      side: const BorderSide(color: Color(0xFF0F766E)),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: targetUserId)),
                                      );
                                    },
                                    child: const Text('Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStoryItem({
    required String name,
    required bool isMe,
    String? avatarUrl,
    VoidCallback? onTapAvatar,
    VoidCallback? onTapAdd,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: onTapAvatar,
                child: Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFF43F5E), Color(0xFFFB923C), Color(0xFFFACC15)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                    ),
                  ),
                ),
              ),
              if (isMe)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onTapAdd,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 68,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String text, int tabIndex) {
    final isActive = _activeTabIndex == tabIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTabIndex = tabIndex;
        });
        _fetchFeed();
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? const Color(0xFF0F766E) : Colors.grey.shade500,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 6),
              Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = _currentUserProfile != null ? (_currentUserProfile!['userId'] ?? _currentUserProfile!['id']) : null;
    final myAvatar = _currentUserProfile != null ? _currentUserProfile!['avatarUrl'] : null;
    final myName = _currentUserProfile != null ? (_currentUserProfile!['displayName'] ?? 'You') : 'You';

    final myStories = _stories.where((s) => s['userId'] == myUserId || (s['user'] != null && s['user']['id'] == myUserId)).toList();
    final rawOtherStories = _stories.where((s) => s['userId'] != myUserId && (s['user'] == null || s['user']['id'] != myUserId)).toList();

    // Group other stories by user ID to show 1 circle per user
    final Map<String, List<dynamic>> groupedOtherStories = {};
    for (var s in rawOtherStories) {
      final uId = s['userId'] ?? (s['user'] != null ? s['user']['id'] : 'unknown');
      groupedOtherStories.putIfAbsent(uId, () => []).add(s);
    }
    final otherUsersList = groupedOtherStories.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchStories();
          await _fetchFeed();
        },
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
              _addStory();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    DateFormat('EEEE · MMMM d').format(DateTime.now()).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Title & "+ Post" Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Where will you go next?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B1B2B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _openCreatePostModal,
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, color: Color(0xFF0F766E), size: 18),
                              SizedBox(width: 4),
                              Text(
                                'Post',
                                style: TextStyle(
                                  color: Color(0xFF0F766E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Stories Row
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: otherUsersList.length + 1,
                      itemBuilder: (context, idx) {
                        if (idx == 0) {
                          return _buildStoryItem(
                            name: 'Your story',
                            isMe: true,
                            avatarUrl: myAvatar,
                            onTapAvatar: () {
                              if (myStories.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StoryViewerScreen(
                                      stories: myStories,
                                      initialIndex: 0,
                                      currentUserId: myUserId ?? '',
                                    ),
                                  ),
                                );
                              } else {
                                _addStory();
                              }
                            },
                            onTapAdd: _addStory,
                          );
                        }
                        final userStories = otherUsersList[idx - 1];
                        final firstStory = userStories.first;
                        final user = firstStory['user'];
                        final profile = user != null ? user['profile'] : null;
                        final sName = profile != null ? profile['displayName'] : 'Story';
                        final sAvatar = profile != null ? profile['avatarUrl'] : null;

                        return _buildStoryItem(
                          name: sName,
                          isMe: false,
                          avatarUrl: sAvatar,
                          onTapAvatar: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoryViewerScreen(
                                  stories: userStories,
                                  initialIndex: 0,
                                  currentUserId: myUserId ?? '',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Publisher Card
                  GestureDetector(
                    onTap: _openCreatePostModal,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Share a travel moment, ${myName.split(' ')[0]}...',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Feed Tab Title
                  Row(
                    children: [
                      _buildTabItem('For you', _ExploreTabFilter.forYou),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0xFFECECE8)),
                  const SizedBox(height: 16),

                  // Feed Posts List
                  if (_loadingFeed && _posts.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF0F766E))))
                  else if (_posts.isEmpty && !_loadingFeed)
                    const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No posts yet. Create the first post!', style: TextStyle(color: Colors.grey))))
                  else
                    ..._posts.map((post) => _buildPostCard(post)),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(dynamic post) {
    final user = post['user'];
    final profile = user != null ? user['profile'] : null;
    final avatar = profile != null ? profile['avatarUrl'] : null;
    final name = profile != null ? profile['displayName'] : 'Traveler';
    final handle = profile != null ? profile['handle'] : 'user';

    final mediaList = post['media'] as List<dynamic>? ?? [];
    final originalPost = post['originalPost'];

    bool isLiked = post['isLikedByMe'] ?? false;
    int likeCount = post['likeCount'] ?? 0;
    bool isSaved = post['isSavedByMe'] ?? false;
    int commentCount = post['commentCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post User Info Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: post['userId'])),
                    );
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? NetworkImage(avatar)
                        : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: post['userId'])),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B1B2B),
                          ),
                        ),
                        Text(
                          '@$handle · Recent',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  onPressed: () => _showPostOptionsSheet(post),
                ),
              ],
            ),
          ),

          // Post Body Text
          if ((post['text'] as String?)?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                post['text'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2E2E2E),
                  height: 1.45,
                ),
              ),
            ),

          // Reshared / Original Post Container (Facebook-style)
          if (originalPost != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: originalPost['userId'])),
                            );
                          },
                          child: CircleAvatar(
                            radius: 14,
                            backgroundImage: (originalPost['user']?['profile']?['avatarUrl'] != null)
                                ? NetworkImage(originalPost['user']['profile']['avatarUrl'])
                                : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          originalPost['user']?['profile']?['displayName'] ?? 'Original Author',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      originalPost['text'] ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Post Media Attachment
          if (mediaList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Builder(
                builder: (context) {
                  int currentPage = 0;
                  return StatefulBuilder(
                    builder: (context, setCarouselState) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 280,
                              child: PageView.builder(
                                itemCount: mediaList.length,
                                onPageChanged: (index) {
                                  setCarouselState(() {
                                    currentPage = index;
                                  });
                                },
                                itemBuilder: (c, idx) {
                                  return Image.network(
                                    mediaList[idx]['mediaUrl'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (c, e, s) => Container(color: Colors.grey.shade100),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Dot Indicators
                          if (mediaList.length > 1)
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  mediaList.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: currentPage == index ? const Color(0xFF0F766E) : Colors.white.withValues(alpha: 0.5),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2)
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Location tag
                          if ((post['location'] as String?)?.isNotEmpty ?? false)
                            Positioned(
                              left: 12,
                              top: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      post['location'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          // Instagram-style Likes Formatted Text Row
          _buildInstagramLikesRow(post),

          // Bottom Action Bar
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Like Button
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.grey,
                      ),
                      onPressed: () async {
                        try {
                          final res = await _apiClient.dio.post('/feed/posts/${post['id']}/react');
                          setState(() {
                            post['isLikedByMe'] = res.data['liked'];
                            post['likeCount'] = res.data['count'];
                          });
                          _fetchFeed();
                        } catch (e) {
                          debugPrint('Post react error: $e');
                        }
                      },
                    ),
                  ],
                ),

                // Comment Button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                      onPressed: () => _openCommentsSheet(post),
                    ),
                    if (commentCount > 0)
                      Text('$commentCount', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),

                // Save / Bookmark Button
                IconButton(
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_outline,
                    color: isSaved ? const Color(0xFF0F766E) : Colors.grey,
                  ),
                  onPressed: () async {
                    try {
                      final res = await _apiClient.dio.post('/feed/posts/${post['id']}/save');
                      setState(() {
                        post['isSavedByMe'] = res.data['saved'];
                      });
                    } catch (e) {
                      debugPrint('Post save error: $e');
                    }
                  },
                ),

                // Share Button
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.grey),
                  onPressed: () => _openShareModal(post),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
