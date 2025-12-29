import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/wink_theme.dart';
import '../../../discovery/domain/models/discoverable_entity.dart';
import 'chat_page.dart';

/// Chat list page showing all conversations
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<ConversationPreview> _aiChats = [];
  List<ConversationPreview> _userChats = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  String? _error;

  List<ConversationPreview> get _filteredAiChats {
    if (_searchQuery.isEmpty) return _aiChats;
    return _aiChats.where((chat) {
      return chat.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (chat.nameZh?.contains(_searchQuery) ?? false) ||
          chat.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<ConversationPreview> get _filteredUserChats {
    if (_searchQuery.isEmpty) return _userChats;
    return _userChats.where((chat) {
      return chat.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          chat.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConversations();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load conversations from Supabase
      final response = await _supabase
          .from('conversations')
          .select('''
            id,
            conversation_type,
            last_message_at,
            last_message_preview,
            unread_count,
            persona:virtual_personas(id, name, name_zh, avatar_url, slug),
            other_user:users!conversations_other_user_id_fkey(id, display_name, avatar_url)
          ''')
          .eq('user_id', userId)
          .order('last_message_at', ascending: false);

      final List<ConversationPreview> ai = [];
      final List<ConversationPreview> users = [];

      for (final row in response as List) {
        final preview = ConversationPreview.fromJson(row);
        if (preview.isAI) {
          ai.add(preview);
        } else {
          users.add(preview);
        }
      }

      setState(() {
        _aiChats = ai;
        _userChats = users;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load conversations';
      });
    }
  }

  void _openChat(ConversationPreview chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: chat.id,
          entityId: chat.entityId,
          entityType: chat.entityType,
          name: chat.name,
          nameZh: chat.nameZh,
          avatarUrl: chat.avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WinkTheme.background,
      appBar: AppBar(
        backgroundColor: WinkTheme.surface,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: WinkTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: TextStyle(color: WinkTheme.textSecondary),
                  border: InputBorder.none,
                ),
              )
            : const Text(
                'Messages',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
            : null,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: WinkTheme.primary,
          labelColor: WinkTheme.primary,
          unselectedLabelColor: WinkTheme.textSecondary,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 18),
                  const SizedBox(width: 8),
                  const Text('AI Friends'),
                  if (_filteredAiChats.any((c) => c.unreadCount > 0)) ...[
                    const SizedBox(width: 8),
                    _buildUnreadBadge(
                      _filteredAiChats.fold(0, (sum, c) => sum + c.unreadCount),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline, size: 18),
                  const SizedBox(width: 8),
                  const Text('People'),
                  if (_filteredUserChats.any((c) => c.unreadCount > 0)) ...[
                    const SizedBox(width: 8),
                    _buildUnreadBadge(
                      _filteredUserChats.fold(0, (sum, c) => sum + c.unreadCount),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() => _isSearching = true);
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
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChatList(_filteredAiChats, isAI: true),
                    _buildChatList(_filteredUserChats, isAI: false),
                  ],
                ),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: WinkTheme.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChatList(List<ConversationPreview> chats, {required bool isAI}) {
    if (chats.isEmpty) {
      return _buildEmptyState(isAI);
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: WinkTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chat = chats[index];
          return _ChatListTile(
            chat: chat,
            onTap: () => _openChat(chat),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isAI) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAI ? Icons.auto_awesome : Icons.people_outline,
            size: 64,
            color: WinkTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isAI ? 'No AI conversations yet' : 'No conversations yet',
            style: TextStyle(
              color: WinkTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAI
                ? 'Discover AI friends in the cosmos!'
                : 'Start connecting with people!',
            style: TextStyle(
              color: WinkTheme.textSecondary.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to discovery
              Navigator.pop(context);
            },
            icon: const Icon(Icons.explore),
            label: const Text('Explore'),
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
            onPressed: _loadConversations,
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

class _ChatListTile extends StatelessWidget {
  final ConversationPreview chat;
  final VoidCallback onTap;

  const _ChatListTile({
    required this.chat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(chat.avatarUrl),
            onBackgroundImageError: (_, __) {},
            backgroundColor: WinkTheme.surface,
          ),
          if (chat.isAI)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: WinkTheme.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: WinkTheme.background, width: 2),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            ),
          if (chat.isOnline && !chat.isAI)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: WinkTheme.background, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.name,
              style: TextStyle(
                fontWeight:
                    chat.unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                color: WinkTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatTime(chat.lastMessageAt),
            style: TextStyle(
              fontSize: 12,
              color: chat.unreadCount > 0
                  ? WinkTheme.primary
                  : WinkTheme.textSecondary,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              chat.lastMessage,
              style: TextStyle(
                color: chat.unreadCount > 0
                    ? WinkTheme.textPrimary
                    : WinkTheme.textSecondary,
                fontWeight:
                    chat.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: WinkTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return '${time.month}/${time.day}';
    }
  }
}

/// Model for conversation preview in the list
class ConversationPreview {
  final String id;
  final String entityId;
  final EntityType entityType;
  final String name;
  final String? nameZh;
  final String avatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isOnline;

  ConversationPreview({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.name,
    this.nameZh,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  bool get isAI => entityType == EntityType.persona;

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    final isAI = json['conversation_type'] == 'user_to_ai';
    final persona = json['persona'] as Map<String, dynamic>?;
    final otherUser = json['other_user'] as Map<String, dynamic>?;

    return ConversationPreview(
      id: json['id'] as String,
      entityId: isAI
          ? (persona?['id'] as String? ?? '')
          : (otherUser?['id'] as String? ?? ''),
      entityType: isAI ? EntityType.persona : EntityType.user,
      name: isAI
          ? (persona?['name'] as String? ?? 'Unknown')
          : (otherUser?['display_name'] as String? ?? 'Unknown'),
      nameZh: isAI ? persona?['name_zh'] as String? : null,
      avatarUrl: isAI
          ? (persona?['avatar_url'] as String? ??
              'https://api.dicebear.com/7.x/personas/png?seed=default')
          : (otherUser?['avatar_url'] as String? ??
              'https://api.dicebear.com/7.x/avataaars/png?seed=default'),
      lastMessage: json['last_message_preview'] as String? ?? '',
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : DateTime.now(),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
