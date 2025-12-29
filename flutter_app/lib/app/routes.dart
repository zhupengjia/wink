import 'package:flutter/material.dart';
import '../features/discovery/presentation/pages/discovery_page.dart';
import '../features/chat/presentation/pages/chat_list_page.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/discovery/domain/models/discoverable_entity.dart';

/// App route names
class AppRoutes {
  static const String discovery = '/';
  static const String chatList = '/chats';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String settings = '/settings';
}

/// Route arguments for chat page
class ChatRouteArgs {
  final String conversationId;
  final String entityId;
  final EntityType entityType;
  final String name;
  final String? nameZh;
  final String avatarUrl;

  ChatRouteArgs({
    required this.conversationId,
    required this.entityId,
    required this.entityType,
    required this.name,
    this.nameZh,
    required this.avatarUrl,
  });
}

/// App router for generating routes
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.discovery:
        return MaterialPageRoute(
          builder: (_) => const DiscoveryPage(),
        );

      case AppRoutes.chatList:
        return MaterialPageRoute(
          builder: (_) => const ChatListPage(),
        );

      case AppRoutes.chat:
        final args = settings.arguments as ChatRouteArgs;
        return MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: args.conversationId,
            entityId: args.entityId,
            entityType: args.entityType,
            name: args.name,
            nameZh: args.nameZh,
            avatarUrl: args.avatarUrl,
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}

/// Navigation extension for easy access
extension NavigatorExtension on BuildContext {
  void goToDiscovery() {
    Navigator.pushNamedAndRemoveUntil(
      this,
      AppRoutes.discovery,
      (route) => false,
    );
  }

  void goToChatList() {
    Navigator.pushNamed(this, AppRoutes.chatList);
  }

  void goToChat({
    required String conversationId,
    required String entityId,
    required EntityType entityType,
    required String name,
    String? nameZh,
    required String avatarUrl,
  }) {
    Navigator.pushNamed(
      this,
      AppRoutes.chat,
      arguments: ChatRouteArgs(
        conversationId: conversationId,
        entityId: entityId,
        entityType: entityType,
        name: name,
        nameZh: nameZh,
        avatarUrl: avatarUrl,
      ),
    );
  }
}
