import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/discoverable_entity.dart';
import '../widgets/planet_view.dart';
import '../../../../core/theme/wink_theme.dart';
import '../../../../shared/widgets/glassmorphic_card.dart';
import '../../../../core/services/api_service.dart';
import '../../../chat/presentation/pages/chat_page.dart';

/// The main discovery page with 3D planet view
class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final _supabase = Supabase.instance.client;
  final _random = Random();

  List<DiscoverableEntity> _entities = [];
  DiscoverableEntity? _selectedEntity;
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'ai', 'users'
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Future<void> _loadEntities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<DiscoverableEntity> entities = [];

      // Load AI personas
      if (_filter == 'all' || _filter == 'ai') {
        final personas = await ApiService.instance.getPersonas();
        for (var i = 0; i < personas.length; i++) {
          final p = personas[i];
          entities.add(DiscoverableEntity(
            id: p.id,
            type: EntityType.persona,
            name: p.name,
            nameZh: p.nameZh,
            avatarUrl: p.avatarUrl,
            bio: p.bio,
            archetype: p.archetype,
            x: _randomPosition(),
            y: _randomPosition(),
            z: 0.3 + _random.nextDouble() * 0.4,
          ));
        }
      }

      // Load online users (if not AI-only filter)
      if (_filter == 'all' || _filter == 'users') {
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          final response = await _supabase
              .from('users')
              .select('id, display_name, avatar_url, bio')
              .neq('id', userId)
              .limit(20);

          for (final user in response as List) {
            entities.add(DiscoverableEntity(
              id: user['id'] as String,
              type: EntityType.user,
              name: user['display_name'] as String? ?? 'User',
              avatarUrl: user['avatar_url'] as String? ??
                  'https://api.dicebear.com/7.x/avataaars/png?seed=${user['id']}',
              bio: user['bio'] as String?,
              x: _randomPosition(),
              y: _randomPosition(),
              z: 0.3 + _random.nextDouble() * 0.4,
            ));
          }
        }
      }

      setState(() {
        _entities = entities;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load entities';
      });
    }
  }

  double _randomPosition() {
    return (_random.nextDouble() - 0.5) * 0.8;
  }

  void _onEntityTap(DiscoverableEntity entity) {
    setState(() => _selectedEntity = entity);
  }

  void _onDismissCard() {
    setState(() => _selectedEntity = null);
  }

  Future<void> _startChat() async {
    if (_selectedEntity == null) return;

    final entity = _selectedEntity!;

    try {
      // Get or create conversation
      final conversation = await ApiService.instance.getOrCreateConversation(
        personaId: entity.type == EntityType.persona ? entity.id : null,
        userId: entity.type == EntityType.user ? entity.id : null,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: conversation.id,
              entityId: entity.id,
              entityType: entity.type,
              name: entity.name,
              nameZh: entity.nameZh,
              avatarUrl: entity.avatarUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start chat')),
        );
      }
    }
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WinkTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: WinkTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Filter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: WinkTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _FilterOption(
              icon: Icons.public,
              label: 'All',
              isSelected: _filter == 'all',
              onTap: () {
                Navigator.pop(context);
                setState(() => _filter = 'all');
                _loadEntities();
              },
            ),
            _FilterOption(
              icon: Icons.auto_awesome,
              label: 'AI Friends',
              isSelected: _filter == 'ai',
              onTap: () {
                Navigator.pop(context);
                setState(() => _filter = 'ai');
                _loadEntities();
              },
            ),
            _FilterOption(
              icon: Icons.people,
              label: 'People',
              isSelected: _filter == 'users',
              onTap: () {
                Navigator.pop(context);
                setState(() => _filter = 'users');
                _loadEntities();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
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
            onPressed: _loadEntities,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 3D Planet View
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: WinkTheme.primary),
            )
          else if (_error != null)
            _buildErrorState()
          else
            PlanetView(
              entities: _entities,
              onEntityTap: _onEntityTap,
              selectedEntity: _selectedEntity,
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Discover',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: WinkTheme.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        color: WinkTheme.textSecondary,
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _loadEntities();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        color: _filter != 'all'
                            ? WinkTheme.primary
                            : WinkTheme.textSecondary,
                        onPressed: _showFilterOptions,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Selected entity card
          if (_selectedEntity != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    _onDismissCard();
                  }
                },
                child: GlassmorphicCard(
                  child: _buildEntityCard(_selectedEntity!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEntityCard(DiscoverableEntity entity) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: entity.type == EntityType.persona
                        ? WinkTheme.personaNode
                        : WinkTheme.userNode,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (entity.type == EntityType.persona
                              ? WinkTheme.personaNode
                              : WinkTheme.userNode)
                          .withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundImage: NetworkImage(entity.avatarUrl),
                  onBackgroundImageError: (_, __) {},
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entity.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: WinkTheme.textPrimary,
                          ),
                        ),
                        if (entity.type == EntityType.persona) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: WinkTheme.secondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'AI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (entity.archetype != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          entity.archetype!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: WinkTheme.primary.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    if (entity.bio != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          entity.bio!,
                          style: TextStyle(
                            color: WinkTheme.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: WinkTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Start Chat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? WinkTheme.primary : WinkTheme.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? WinkTheme.primary : WinkTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: WinkTheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
