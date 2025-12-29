import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/wink_theme.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_sheet.dart';

/// Square page - Timeline/feed of posts from users and AI personas
class SquarePage extends StatefulWidget {
  const SquarePage({super.key});

  @override
  State<SquarePage> createState() => _SquarePageState();
}

class _SquarePageState extends State<SquarePage> {
  final _supabase = Supabase.instance.client;
  final _scrollController = ScrollController();

  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _lastPostId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabase
          .from('posts')
          .select('''
            id,
            content,
            media_urls,
            created_at,
            like_count,
            comment_count,
            user:users(id, display_name, avatar_url),
            persona:virtual_personas(id, name, name_zh, avatar_url, slug)
          ''')
          .order('created_at', ascending: false)
          .limit(20);

      final posts = (response as List).map((json) => Post.fromJson(json)).toList();

      setState(() {
        _posts = posts;
        _lastPostId = posts.isNotEmpty ? posts.last.id : null;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load posts';
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || _lastPostId == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final response = await _supabase
          .from('posts')
          .select('''
            id,
            content,
            media_urls,
            created_at,
            like_count,
            comment_count,
            user:users(id, display_name, avatar_url),
            persona:virtual_personas(id, name, name_zh, avatar_url, slug)
          ''')
          .lt('id', _lastPostId!)
          .order('created_at', ascending: false)
          .limit(20);

      final posts = (response as List).map((json) => Post.fromJson(json)).toList();

      setState(() {
        _posts.addAll(posts);
        _lastPostId = posts.isNotEmpty ? posts.last.id : null;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _showCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePostSheet(
        onPost: (content, mediaUrls) async {
          await _createPost(content, mediaUrls);
        },
      ),
    );
  }

  Future<void> _createPost(String content, List<String> mediaUrls) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('posts').insert({
        'user_id': userId,
        'content': content,
        'media_urls': mediaUrls,
      });

      _loadPosts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    }
  }

  Future<void> _toggleLike(Post post) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _posts[index] = post.copyWith(
          isLiked: !post.isLiked,
          likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
        );
      }
    });

    try {
      if (post.isLiked) {
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', userId);
      } else {
        await _supabase.from('post_likes').insert({
          'post_id': post.id,
          'user_id': userId,
        });
      }
    } catch (e) {
      // Revert on error
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = post;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WinkTheme.background,
      appBar: AppBar(
        backgroundColor: WinkTheme.surface,
        title: const Text(
          'Square',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Show notifications
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: WinkTheme.primary),
            )
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  color: WinkTheme.primary,
                  child: _posts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _posts.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: WinkTheme.primary,
                              ),
                            ),
                          );
                        }

                        final post = _posts[index];
                        return PostCard(
                          post: post,
                          onLike: () => _toggleLike(post),
                          onComment: () {
                            // Open comments
                          },
                          onShare: () {
                            // Share post
                          },
                          onAuthorTap: () {
                            // Navigate to profile
                          },
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePost,
        backgroundColor: WinkTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.grid_view,
            size: 64,
            color: WinkTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              color: WinkTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something!',
            style: TextStyle(
              color: WinkTheme.textSecondary.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Something went wrong',
            style: TextStyle(
              color: WinkTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadPosts,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WinkTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Post model
class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorNameZh;
  final String authorAvatar;
  final bool isAI;
  final String content;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool isLiked;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorNameZh,
    required this.authorAvatar,
    required this.isAI,
    required this.content,
    required this.mediaUrls,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
  });

  Post copyWith({
    int? likeCount,
    bool? isLiked,
  }) {
    return Post(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorNameZh: authorNameZh,
      authorAvatar: authorAvatar,
      isAI: isAI,
      content: content,
      mediaUrls: mediaUrls,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final persona = json['persona'] as Map<String, dynamic>?;
    final isAI = persona != null;

    return Post(
      id: json['id'] as String,
      authorId: isAI
          ? (persona?['id'] as String? ?? '')
          : (user?['id'] as String? ?? ''),
      authorName: isAI
          ? (persona?['name'] as String? ?? 'Unknown')
          : (user?['display_name'] as String? ?? 'Unknown'),
      authorNameZh: isAI ? persona?['name_zh'] as String? : null,
      authorAvatar: isAI
          ? (persona?['avatar_url'] as String? ?? '')
          : (user?['avatar_url'] as String? ?? ''),
      isAI: isAI,
      content: json['content'] as String? ?? '',
      mediaUrls: (json['media_urls'] as List?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      isLiked: false, // Need separate query for user's likes
    );
  }
}
