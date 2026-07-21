import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../profile/profile_screen.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<dynamic> stories;
  final int initialIndex;
  final String currentUserId;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    required this.currentUserId,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _replyController = TextEditingController();

  late int _currentIndex;
  late AnimationController _animController;
  bool _isPaused = false;
  bool _liked = false;
  int _viewCount = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSegmentComplete();
      }
    });

    _loadCurrentStory();
  }

  @override
  void dispose() {
    _animController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _loadCurrentStory() {
    if (_currentIndex < 0 || _currentIndex >= widget.stories.length) return;
    final story = widget.stories[_currentIndex];

    setState(() {
      _liked = story['isLikedByMe'] ?? false;
      _viewCount = story['viewCount'] ?? 1;
    });

    // Record view on backend
    _apiClient.dio.post('/feed/stories/${story['id']}/view').then((res) {
      if (mounted && res.data['count'] != null) {
        setState(() {
          _viewCount = res.data['count'];
        });
      }
    }).catchError((e) {
      debugPrint('Story view record error: $e');
    });

    _animController.reset();
    _animController.forward();
  }

  void _onSegmentComplete() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadCurrentStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _pauseTimer() {
    setState(() {
      _isPaused = true;
    });
    _animController.stop();
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
    });
    _animController.forward();
  }

  void _goPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadCurrentStory();
    } else {
      _animController.reset();
      _animController.forward();
    }
  }

  void _goNext() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadCurrentStory();
    } else {
      Navigator.pop(context);
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

  void _confirmDeleteStory(dynamic story) {
    _pauseTimer();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete story?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete this story? It will be permanently removed.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resumeTimer();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await _apiClient.dio.delete('/feed/stories/${story['id']}');
                  if (mounted) {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Story deleted successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete story failed: $e'), backgroundColor: Colors.red),
                  );
                  _resumeTimer();
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showViewersSheet(dynamic story) {
    _pauseTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder(
          future: _apiClient.dio.get('/feed/stories/${story['id']}/viewers'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF0F766E))),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 200,
                child: Center(child: Text('Failed to load viewers: ${snapshot.error}')),
              );
            }

            final viewers = (snapshot.data?.data as List<dynamic>?) ?? [];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
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
                        'Story Views (${viewers.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  SizedBox(
                    height: 300,
                    child: viewers.isEmpty
                        ? const Center(child: Text('No viewers yet.', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: viewers.length,
                            separatorBuilder: (c, i) => const Divider(height: 1),
                            itemBuilder: (c, idx) {
                              final v = viewers[idx];
                              final avatar = v['avatarUrl'];
                              final name = v['name'] ?? 'Traveler';
                              final handle = v['handle'] ?? 'user';
                              final isLiked = v['isLiked'] ?? false;

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                                      ? NetworkImage(avatar)
                                      : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('@$handle', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                trailing: isLiked
                                    ? const Icon(Icons.favorite, color: Colors.red, size: 18)
                                    : const Icon(Icons.remove_red_eye_outlined, color: Colors.grey, size: 18),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.pop(context); // Close story viewer
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: v['id'])),
                                  );
                                },
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
    ).then((_) {
      _resumeTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex < 0 || _currentIndex >= widget.stories.length) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final currentStory = widget.stories[_currentIndex];
    final user = currentStory['user'];
    final profile = user != null ? user['profile'] : null;
    final avatar = profile != null ? profile['avatarUrl'] : null;
    final name = profile != null ? profile['displayName'] : 'User';
    final storyUserId = currentStory['userId'];
    final isMyStory = storyUserId == widget.currentUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onLongPressStart: (_) => _pauseTimer(),
          onLongPressEnd: (_) => _resumeTimer(),
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
              if (isMyStory) {
                _showViewersSheet(currentStory);
              }
            }
          },
          child: Stack(
            children: [
              // Main Media View
              Positioned.fill(
                child: Image.network(
                  currentStory['mediaUrl'] ?? 'https://picsum.photos/400/800',
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(color: Colors.grey.shade900),
                ),
              ),

              // Left/Right Touch Controls for Manual Traversal
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _goPrevious,
                        child: Container(),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _goNext,
                        child: Container(),
                      ),
                    ),
                  ],
                ),
              ),

              // Top Controls: Segmented Progress Lines & User Header
              if (!_isPaused)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      // Segmented Progress Lines
                      Row(
                        children: List.generate(widget.stories.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: AnimatedBuilder(
                                animation: _animController,
                                builder: (context, child) {
                                  double progress = 0.0;
                                  if (index < _currentIndex) {
                                    progress = 1.0;
                                  } else if (index == _currentIndex) {
                                    progress = _animController.value;
                                  }
                                  return LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white30,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    minHeight: 2.5,
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),

                      // User Header Row
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: storyUserId)),
                              );
                            },
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white24,
                              backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                                  ? NetworkImage(avatar)
                                  : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                                ),
                              ),
                              Text(
                                _getTimeAgo(currentStory['createdAt']),
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (isMyStory)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                              onPressed: () => _confirmDeleteStory(currentStory),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 24),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),


              // Bottom Bar (If My Story -> Viewers Count Sheet; If Other User -> DM Input & Like)
              if (!_isPaused)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: isMyStory
                      ? GestureDetector(
                          onTap: () => _showViewersSheet(currentStory),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '$_viewCount ${_viewCount == 1 ? 'view' : 'views'}  • Swipe up for viewers',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Send message...',
                                  hintStyle: const TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.black45,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(color: Colors.white30),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.send, color: Colors.white),
                                    onPressed: () async {
                                      final text = _replyController.text.trim();
                                      if (text.isEmpty) return;

                                      try {
                                        await _apiClient.dio.post('/feed/stories/${currentStory['id']}/reply', data: {
                                          'text': text,
                                        });
                                        if (mounted) {
                                          _replyController.clear();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Reply sent to inbox!'), backgroundColor: Color(0xFF0F766E)),
                                          );
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Reply failed: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () async {
                                try {
                                  final res = await _apiClient.dio.post('/feed/stories/${currentStory['id']}/like');
                                  setState(() {
                                    _liked = res.data['liked'];
                                  });
                                } catch (e) {
                                  debugPrint('Story like error: $e');
                                }
                              },
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.black45,
                                child: Icon(
                                  _liked ? Icons.favorite : Icons.favorite_border,
                                  color: _liked ? Colors.red : Colors.white,
                                  size: 22,
                                ),
                              ),
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
