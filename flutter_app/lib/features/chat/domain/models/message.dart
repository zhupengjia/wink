/// Represents who sent a message
enum MessageSender { user, other, ai, system }

/// Type of media attachment
enum MediaType { image, video, voice }

/// A chat message
class ChatMessage {
  final String id;
  final String conversationId;
  final MessageSender sender;
  final String? senderName;
  final String? senderAvatar;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  // Media attachment
  final String? mediaUrl;
  final String? thumbnailUrl;
  final MediaType? mediaType;
  final int? mediaDuration; // For video/voice in seconds

  // AI-specific metadata
  final String? intimacyTier;
  final bool isStreaming;
  final String? modelUsed;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    this.senderName,
    this.senderAvatar,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaType,
    this.mediaDuration,
    this.intimacyTier,
    this.isStreaming = false,
    this.modelUsed,
  });

  /// Whether this message is from the current user
  bool get isFromMe => sender == MessageSender.user;

  /// Whether this message has media attached
  bool get hasMedia => mediaUrl != null;

  /// Whether this message is from an AI persona
  bool get isFromAI => sender == MessageSender.ai;

  /// Create a copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? conversationId,
    MessageSender? sender,
    String? senderName,
    String? senderAvatar,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    String? mediaUrl,
    String? thumbnailUrl,
    MediaType? mediaType,
    int? mediaDuration,
    String? intimacyTier,
    bool? isStreaming,
    String? modelUsed,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      sender: sender ?? this.sender,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mediaType: mediaType ?? this.mediaType,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      intimacyTier: intimacyTier ?? this.intimacyTier,
      isStreaming: isStreaming ?? this.isStreaming,
      modelUsed: modelUsed ?? this.modelUsed,
    );
  }

  /// Create from JSON (API response)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      sender: _parseSender(json['sender_type'] as String?),
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
      content: json['content'] as String? ?? '',
      timestamp: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      mediaUrl: json['media_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      mediaType: _parseMediaType(json['media_type'] as String?),
      mediaDuration: json['media_duration'] as int?,
      intimacyTier: json['intimacy_tier_at_send'] as String?,
      isStreaming: false,
      modelUsed: json['model_used'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_type': _senderToString(sender),
      'content': content,
      'created_at': timestamp.toIso8601String(),
      'is_read': isRead,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'media_type': mediaType?.name,
      'media_duration': mediaDuration,
    };
  }

  static MessageSender _parseSender(String? type) {
    switch (type) {
      case 'user':
        return MessageSender.user;
      case 'ai':
        return MessageSender.ai;
      case 'system':
        return MessageSender.system;
      default:
        return MessageSender.other;
    }
  }

  static String _senderToString(MessageSender sender) {
    switch (sender) {
      case MessageSender.user:
        return 'user';
      case MessageSender.ai:
        return 'ai';
      case MessageSender.system:
        return 'system';
      case MessageSender.other:
        return 'other';
    }
  }

  static MediaType? _parseMediaType(String? type) {
    switch (type) {
      case 'image':
        return MediaType.image;
      case 'video':
        return MediaType.video;
      case 'voice':
        return MediaType.voice;
      default:
        return null;
    }
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, sender: $sender, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// A conversation between users or user and AI
class Conversation {
  final String id;
  final String userId;
  final String? otherUserId;
  final String? personaId;
  final String conversationType; // 'user_to_user' or 'user_to_ai'
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;

  // Populated from joins
  final String? otherUserName;
  final String? otherUserAvatar;
  final String? personaName;
  final String? personaAvatar;

  const Conversation({
    required this.id,
    required this.userId,
    this.otherUserId,
    this.personaId,
    required this.conversationType,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.otherUserName,
    this.otherUserAvatar,
    this.personaName,
    this.personaAvatar,
  });

  /// Whether this is an AI conversation
  bool get isAIConversation => conversationType == 'user_to_ai';

  /// Get the display name for the other participant
  String get participantName {
    if (isAIConversation) {
      return personaName ?? 'AI';
    }
    return otherUserName ?? 'User';
  }

  /// Get the avatar URL for the other participant
  String? get participantAvatar {
    if (isAIConversation) {
      return personaAvatar;
    }
    return otherUserAvatar;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      otherUserId: json['other_user_id'] as String?,
      personaId: json['persona_id'] as String?,
      conversationType: json['conversation_type'] as String,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessagePreview: json['last_message_preview'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      otherUserName: json['other_user']?['display_name'] as String?,
      otherUserAvatar: json['other_user']?['avatar_url'] as String?,
      personaName: json['persona']?['name'] as String?,
      personaAvatar: json['persona']?['avatar_url'] as String?,
    );
  }
}
