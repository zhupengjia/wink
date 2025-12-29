import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/message.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/intimacy_bar.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/intimacy_details_sheet.dart';
import '../widgets/media_viewer.dart';
import '../widgets/voice_recorder.dart';
import '../../../discovery/domain/models/discoverable_entity.dart';
import '../../../../core/theme/wink_theme.dart';
import '../../../../core/services/api_service.dart';

/// Full chat page for conversations with users or AI personas
class ChatPage extends StatefulWidget {
  final String conversationId;
  final String entityId;
  final EntityType entityType;
  final String name;
  final String? nameZh;
  final String avatarUrl;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.entityId,
    required this.entityType,
    required this.name,
    this.nameZh,
    required this.avatarUrl,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  StreamSubscription? _realtimeSubscription;

  bool _isLoading = false;
  bool _isTyping = false;
  bool _isInitialLoading = true;

  // AI-specific state
  int _intimacyScore = 0;
  String _intimacyTier = 'stranger';
  int? _recentGain;

  // Streaming
  String _streamingContent = '';
  String? _streamingMessageId;

  // Voice recording
  bool _isRecordingVoice = false;

  bool get _isAIChat => widget.entityType == EntityType.persona;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadMessages(),
      if (_isAIChat) _loadIntimacy(),
    ]);

    // Subscribe to realtime messages for user-to-user chat
    if (!_isAIChat) {
      _subscribeToMessages();
    }

    setState(() => _isInitialLoading = false);
  }

  void _subscribeToMessages() {
    _realtimeSubscription = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('created_at')
        .listen((data) {
      final newMessages = data
          .map((json) => ChatMessage.fromJson(json, widget.name, widget.avatarUrl))
          .toList();

      // Only add messages that aren't already in the list
      for (final msg in newMessages) {
        if (!_messages.any((m) => m.id == msg.id)) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await ApiService.instance.getMessages(
        conversationId: widget.conversationId,
        limit: 50,
      );

      setState(() {
        _messages.clear();
        _messages.addAll(
          messages.map((m) => ChatMessage(
            id: m.id,
            conversationId: m.conversationId,
            sender: m.senderType == 'user' ? MessageSender.user : MessageSender.ai,
            senderName: m.senderType == 'ai' ? widget.name : null,
            senderAvatar: m.senderType == 'ai' ? widget.avatarUrl : null,
            content: m.content,
            timestamp: m.createdAt,
            mediaUrl: m.mediaUrl,
            mediaType: m.mediaType,
          )).toList(),
        );
      });

      // If no messages, add welcome message for AI
      if (_messages.isEmpty && _isAIChat) {
        setState(() {
          _messages.add(ChatMessage(
            id: 'welcome_msg',
            conversationId: widget.conversationId,
            sender: MessageSender.ai,
            senderName: widget.name,
            senderAvatar: widget.avatarUrl,
            content: _getWelcomeMessage(),
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      // Fallback to welcome message
      if (_isAIChat) {
        setState(() {
          _messages.add(ChatMessage(
            id: 'welcome_msg',
            conversationId: widget.conversationId,
            sender: MessageSender.ai,
            senderName: widget.name,
            senderAvatar: widget.avatarUrl,
            content: _getWelcomeMessage(),
            timestamp: DateTime.now(),
          ));
        });
      }
    }
  }

  String _getWelcomeMessage() {
    // Different welcome based on persona
    return "Hey there! I noticed you floating by in the cosmos. What brings you my way today?";
  }

  Future<void> _loadIntimacy() async {
    try {
      final intimacy = await ApiService.instance.getIntimacy(widget.entityId);
      setState(() {
        _intimacyScore = intimacy.score;
        _intimacyTier = intimacy.tier;
      });
    } catch (e) {
      // Use defaults
      setState(() {
        _intimacyScore = 0;
        _intimacyTier = 'stranger';
      });
    }
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversationId,
      sender: MessageSender.user,
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      if (_isAIChat) _isTyping = true;
    });

    _scrollToBottom();

    if (_isAIChat) {
      await _sendToAI(text);
    } else {
      await _sendToUser(text);
    }
  }

  Future<void> _sendToAI(String text) async {
    setState(() {
      _streamingContent = '';
      _streamingMessageId = 'msg_ai_${DateTime.now().millisecondsSinceEpoch}';
    });

    // Add streaming message placeholder
    _messages.add(ChatMessage(
      id: _streamingMessageId!,
      conversationId: widget.conversationId,
      sender: MessageSender.ai,
      senderName: widget.name,
      senderAvatar: widget.avatarUrl,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    ));

    try {
      // Try streaming first
      final stream = ApiService.instance.sendMessageStream(
        conversationId: widget.conversationId,
        content: text,
      );

      setState(() => _isTyping = false);

      await for (final chunk in stream) {
        setState(() {
          _streamingContent += chunk;
          final index = _messages.indexWhere((m) => m.id == _streamingMessageId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(content: _streamingContent);
          }
        });
        _scrollToBottom();
      }

      // Finalize message
      setState(() {
        final index = _messages.indexWhere((m) => m.id == _streamingMessageId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(isStreaming: false);
        }
        _isLoading = false;
        _streamingMessageId = null;
      });

      // Reload intimacy to get updated score
      await _loadIntimacy();
    } catch (e) {
      // Fallback to non-streaming
      try {
        setState(() => _isTyping = false);

        final response = await ApiService.instance.sendMessage(
          conversationId: widget.conversationId,
          content: text,
        );

        setState(() {
          final index = _messages.indexWhere((m) => m.id == _streamingMessageId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              id: response.messageId,
              content: response.content,
              isStreaming: false,
            );
          }
          _isLoading = false;
          _streamingMessageId = null;

          // Update intimacy from response
          if (response.intimacyGain != null) {
            _recentGain = response.intimacyGain;
            _intimacyScore += response.intimacyGain!;
          }
          if (response.newTier != null) {
            _intimacyTier = response.newTier!;
          }
        });

        // Clear gain indicator after delay
        if (_recentGain != null) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _recentGain = null);
          });
        }
      } catch (e2) {
        // Show error
        setState(() {
          final index = _messages.indexWhere((m) => m.id == _streamingMessageId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              content: 'Sorry, I couldn\'t respond right now. Please try again.',
              isStreaming: false,
            );
          }
          _isLoading = false;
          _streamingMessageId = null;
        });
      }
    }
  }

  Future<void> _sendToUser(String text) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Insert message directly into Supabase
      await _supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_type': 'user',
        'sender_user_id': userId,
        'role': 'user',
        'content': text,
      });

      // Update conversation
      await _supabase.from('conversations').update({
        'last_message_at': DateTime.now().toIso8601String(),
        'last_message_preview': text.length > 100 ? '${text.substring(0, 100)}...' : text,
      }).eq('id', widget.conversationId);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  String _calculateTier(int score) {
    if (score <= 100) return 'stranger';
    if (score <= 300) return 'acquaintance';
    if (score <= 500) return 'friend';
    if (score <= 750) return 'close';
    return 'intimate';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onMediaTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MediaPickerSheet(
        onPhotoTap: () {
          Navigator.pop(context);
          _pickPhoto();
        },
        onVideoTap: () {
          Navigator.pop(context);
          _pickVideo();
        },
        onVoiceTap: () {
          Navigator.pop(context);
          _recordVoice();
        },
        onCameraTap: () {
          Navigator.pop(context);
          _takePhoto();
        },
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image != null) {
      await _sendMedia(image, 'image');
    }
  }

  Future<void> _pickVideo() async {
    final video = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );

    if (video != null) {
      await _sendMedia(video, 'video');
    }
  }

  void _recordVoice() {
    setState(() => _isRecordingVoice = true);
  }

  Future<void> _sendVoiceMessage(String path, Duration duration) async {
    setState(() {
      _isRecordingVoice = false;
      _isLoading = true;
    });

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final storagePath = 'chat-media/${widget.conversationId}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _supabase.storage.from('wink-storage').uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(contentType: 'audio/mp4'),
      );

      final mediaUrl = _supabase.storage.from('wink-storage').getPublicUrl(storagePath);

      // Add message with voice
      final userId = _supabase.auth.currentUser?.id;
      await _supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_type': 'user',
        'sender_user_id': userId,
        'role': 'user',
        'content': 'Voice message (${duration.inSeconds}s)',
        'media_url': mediaUrl,
        'media_type': 'voice',
      });

      // Add to local messages
      setState(() {
        _messages.add(ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: widget.conversationId,
          sender: MessageSender.user,
          content: 'Voice message (${duration.inSeconds}s)',
          timestamp: DateTime.now(),
          mediaUrl: mediaUrl,
          mediaType: 'voice',
        ));
        _isLoading = false;
      });

      _scrollToBottom();

      // Clean up temp file
      try {
        await file.delete();
      } catch (_) {}
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
    }
  }

  void _cancelVoiceRecording() {
    setState(() => _isRecordingVoice = false);
  }

  Future<void> _takePhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image != null) {
      await _sendMedia(image, 'image');
    }
  }

  Future<void> _sendMedia(XFile file, String mediaType) async {
    setState(() => _isLoading = true);

    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last;
      final path = 'chat-media/${widget.conversationId}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from('wink-storage').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: '$mediaType/$ext'),
      );

      final mediaUrl = _supabase.storage.from('wink-storage').getPublicUrl(path);

      // Add message with media
      final userId = _supabase.auth.currentUser?.id;
      await _supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_type': 'user',
        'sender_user_id': userId,
        'role': 'user',
        'content': '',
        'media_url': mediaUrl,
        'media_type': mediaType,
      });

      // Add to local messages
      setState(() {
        _messages.add(ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: widget.conversationId,
          sender: MessageSender.user,
          content: '',
          timestamp: DateTime.now(),
          mediaUrl: mediaUrl,
          mediaType: mediaType,
        ));
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send media: $e')),
        );
      }
    }
  }

  void _showOptions() {
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
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                _showProfileSheet();
              },
            ),
            if (_isAIChat)
              ListTile(
                leading: const Icon(Icons.favorite_border),
                title: const Text('View Intimacy'),
                subtitle: Text('$_intimacyTier • $_intimacyScore/1000'),
                onTap: () {
                  Navigator.pop(context);
                  _showIntimacyDetails();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Clear Chat', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmClearChat();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: WinkTheme.surface,
        title: const Text('Clear Chat?'),
        content: const Text('This will delete all messages in this conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _messages.clear());
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WinkTheme.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isInitialLoading
                ? const Center(
                    child: CircularProgressIndicator(color: WinkTheme.primary),
                  )
                : _buildMessageList(),
          ),

          // Input
          if (_isRecordingVoice)
            VoiceRecorder(
              onRecordingComplete: _sendVoiceMessage,
              onCancel: _cancelVoiceRecording,
            )
          else
            ChatInput(
              onSend: _sendMessage,
              onMediaTap: _onMediaTap,
              isLoading: _isLoading,
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: WinkTheme.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(widget.avatarUrl),
                onBackgroundImageError: (_, __) {},
              ),
              if (_isAIChat)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: WinkTheme.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: WinkTheme.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isAIChat) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: WinkTheme.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_isTyping)
                  Text(
                    'typing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: WinkTheme.secondary,
                    ),
                  )
                else if (_isAIChat)
                  const Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Intimacy bar for AI chats
        if (_isAIChat)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: IntimacyBar(
                score: _intimacyScore,
                tier: _intimacyTier,
                recentGain: _recentGain,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showOptions,
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        // Typing indicator
        if (_isTyping && index == _messages.length) {
          return TypingIndicator(
            name: widget.name,
            avatarUrl: widget.avatarUrl,
            isAI: _isAIChat,
          );
        }

        final message = _messages[index];
        final showAvatar = index == 0 ||
            _messages[index - 1].sender != message.sender;

        return MessageBubble(
          message: message,
          showAvatar: showAvatar && !message.isFromMe,
          onMediaTap: message.hasMedia
              ? () => _openMediaViewer(message)
              : null,
        );
      },
    );
  }

  void _openMediaViewer(ChatMessage message) {
    if (message.mediaUrl == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewer(
          mediaUrl: message.mediaUrl!,
          mediaType: message.mediaType ?? 'image',
          senderName: message.senderName ?? 'You',
          timestamp: message.timestamp,
        ),
      ),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WinkTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(widget.avatarUrl),
                    onBackgroundImageError: (_, __) {},
                  ),
                  if (_isAIChat)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: WinkTheme.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: WinkTheme.surface, width: 3),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Name
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: WinkTheme.textPrimary,
                ),
              ),
              if (widget.nameZh != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.nameZh!,
                  style: TextStyle(
                    fontSize: 16,
                    color: WinkTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _isAIChat
                      ? WinkTheme.secondary.withOpacity(0.2)
                      : WinkTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isAIChat ? 'AI Companion' : 'User',
                  style: TextStyle(
                    color: _isAIChat ? WinkTheme.secondary : WinkTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Stats for AI
              if (_isAIChat) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ProfileStat(label: 'Score', value: _intimacyScore.toString()),
                    _ProfileStat(label: 'Tier', value: _intimacyTier),
                    _ProfileStat(label: 'Messages', value: _messages.length.toString()),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showIntimacyDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => IntimacyDetailsSheet(
        personaName: widget.name,
        personaAvatar: widget.avatarUrl,
        score: _intimacyScore,
        tier: _intimacyTier,
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: WinkTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: WinkTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
