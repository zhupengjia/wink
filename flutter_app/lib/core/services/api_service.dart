import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// API Service for communicating with the Golang backend
class ApiService {
  static ApiService? _instance;
  late final Dio _dio;
  late final SupabaseClient _supabase;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8080/api',
      ),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _supabase = Supabase.instance.client;

    // Add interceptors
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token
        final session = _supabase.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        // Add user ID header for development
        final user = _supabase.auth.currentUser;
        if (user != null) {
          options.headers['X-User-ID'] = user.id;
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // Handle errors globally
        if (error.response?.statusCode == 401) {
          // Token expired, refresh or logout
          _handleAuthError();
        }
        return handler.next(error);
      },
    ));
  }

  static ApiService get instance {
    _instance ??= ApiService._internal();
    return _instance!;
  }

  Future<void> _handleAuthError() async {
    try {
      // Try to refresh the session
      final response = await _supabase.auth.refreshSession();
      if (response.session != null) {
        // Session refreshed successfully
        return;
      }
    } catch (e) {
      // Refresh failed
    }

    // If refresh failed, sign out and clear state
    await _supabase.auth.signOut();
  }

  // ============================================
  // Chat API
  // ============================================

  /// Send a message to a conversation
  Future<SendMessageResponse> sendMessage({
    required String conversationId,
    required String content,
    String? locale,
  }) async {
    final response = await _dio.post('/chat/send', data: {
      'conversation_id': conversationId,
      'content': content,
      'locale': locale,
    });

    return SendMessageResponse.fromJson(response.data);
  }

  /// Send a message with streaming response
  Stream<String> sendMessageStream({
    required String conversationId,
    required String content,
    String? locale,
  }) async* {
    final response = await _dio.post(
      '/chat/send/stream',
      data: {
        'conversation_id': conversationId,
        'content': content,
        'locale': locale,
      },
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data.stream as Stream<List<int>>;
    await for (final chunk in stream) {
      final text = utf8.decode(chunk);
      yield text;
    }
  }

  // ============================================
  // Persona API
  // ============================================

  /// Get all active personas
  Future<List<PersonaResponse>> getPersonas() async {
    final response = await _dio.get('/personas');
    return (response.data as List)
        .map((json) => PersonaResponse.fromJson(json))
        .toList();
  }

  /// Get a specific persona
  Future<PersonaResponse> getPersona(String personaId) async {
    final response = await _dio.get('/personas/$personaId');
    return PersonaResponse.fromJson(response.data);
  }

  // ============================================
  // Intimacy API
  // ============================================

  /// Get intimacy level with a persona
  Future<IntimacyResponse> getIntimacy(String personaId) async {
    final response = await _dio.get('/intimacy/$personaId');
    return IntimacyResponse.fromJson(response.data);
  }

  // ============================================
  // Conversation API
  // ============================================

  /// Create or get existing conversation with a persona
  Future<ConversationResponse> getOrCreateConversation({
    String? personaId,
    String? userId,
  }) async {
    final response = await _dio.post('/conversations', data: {
      if (personaId != null) 'persona_id': personaId,
      if (userId != null) 'user_id': userId,
    });
    return ConversationResponse.fromJson(response.data);
  }

  /// Get conversation history
  Future<List<MessageResponse>> getMessages({
    required String conversationId,
    int limit = 50,
    String? before,
  }) async {
    final response = await _dio.get('/conversations/$conversationId/messages', queryParameters: {
      'limit': limit,
      if (before != null) 'before': before,
    });
    return (response.data as List)
        .map((json) => MessageResponse.fromJson(json))
        .toList();
  }
}

// ============================================
// Response Models
// ============================================

class SendMessageResponse {
  final String messageId;
  final String content;
  final int? intimacyGain;
  final String? newTier;
  final String timestamp;

  SendMessageResponse({
    required this.messageId,
    required this.content,
    this.intimacyGain,
    this.newTier,
    required this.timestamp,
  });

  factory SendMessageResponse.fromJson(Map<String, dynamic> json) {
    return SendMessageResponse(
      messageId: json['message_id'] as String,
      content: json['content'] as String,
      intimacyGain: json['intimacy_gain'] as int?,
      newTier: json['new_tier'] as String?,
      timestamp: json['timestamp'] as String,
    );
  }
}

class PersonaResponse {
  final String id;
  final String slug;
  final String name;
  final String? nameZh;
  final String avatarUrl;
  final String? bio;
  final String archetype;
  final bool isActive;

  PersonaResponse({
    required this.id,
    required this.slug,
    required this.name,
    this.nameZh,
    required this.avatarUrl,
    this.bio,
    required this.archetype,
    required this.isActive,
  });

  factory PersonaResponse.fromJson(Map<String, dynamic> json) {
    return PersonaResponse(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      nameZh: json['name_zh'] as String?,
      avatarUrl: json['avatar_url'] as String,
      bio: json['bio'] as String?,
      archetype: json['archetype'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class IntimacyResponse {
  final String personaId;
  final int score;
  final String tier;
  final int totalMessages;
  final int streakDays;

  IntimacyResponse({
    required this.personaId,
    required this.score,
    required this.tier,
    required this.totalMessages,
    required this.streakDays,
  });

  factory IntimacyResponse.fromJson(Map<String, dynamic> json) {
    return IntimacyResponse(
      personaId: json['persona_id'] as String,
      score: json['score'] as int,
      tier: json['tier'] as String,
      totalMessages: json['total_messages'] as int? ?? 0,
      streakDays: json['streak_days'] as int? ?? 0,
    );
  }
}

class ConversationResponse {
  final String id;
  final String? personaId;
  final String? otherUserId;
  final String conversationType;
  final DateTime? lastMessageAt;

  ConversationResponse({
    required this.id,
    this.personaId,
    this.otherUserId,
    required this.conversationType,
    this.lastMessageAt,
  });

  factory ConversationResponse.fromJson(Map<String, dynamic> json) {
    return ConversationResponse(
      id: json['id'] as String,
      personaId: json['persona_id'] as String?,
      otherUserId: json['other_user_id'] as String?,
      conversationType: json['conversation_type'] as String,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
    );
  }
}

class MessageResponse {
  final String id;
  final String conversationId;
  final String senderType;
  final String content;
  final DateTime createdAt;
  final String? mediaUrl;
  final String? mediaType;

  MessageResponse({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.content,
    required this.createdAt,
    this.mediaUrl,
    this.mediaType,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderType: json['sender_type'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
    );
  }
}
