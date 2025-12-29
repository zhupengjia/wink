// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Wink';

  @override
  String get discover => 'Discover';

  @override
  String get chat => 'Chat';

  @override
  String get profile => 'Profile';

  @override
  String get square => 'Square';

  @override
  String get settings => 'Settings';

  @override
  String get startChat => 'Start Chat';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get send => 'Send';

  @override
  String get sending => 'Sending...';

  @override
  String get messageSent => 'Message sent';

  @override
  String get messageError => 'Failed to send message';

  @override
  String get typing => 'typing...';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String lastSeen(String time) {
    return 'Last seen $time';
  }

  @override
  String get photoOption => 'Photo';

  @override
  String get videoOption => 'Video';

  @override
  String get voiceOption => 'Voice';

  @override
  String get cameraOption => 'Camera';

  @override
  String get galleryOption => 'Gallery';

  @override
  String get intimacyStranger => 'Stranger';

  @override
  String get intimacyAcquaintance => 'Acquaintance';

  @override
  String get intimacyFriend => 'Friend';

  @override
  String get intimacyClose => 'Close';

  @override
  String get intimacyIntimate => 'Intimate';

  @override
  String intimacyGain(int points) {
    return '+$points';
  }

  @override
  String intimacyLevel(String level) {
    return 'Intimacy: $level';
  }

  @override
  String get aiLabel => 'AI';

  @override
  String get virtualPerson => 'Virtual Person';

  @override
  String messageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
      zero: 'No messages',
    );
    return '$_temp0';
  }

  @override
  String get newConversation => 'New Conversation';

  @override
  String get noConversations => 'No conversations yet';

  @override
  String get startDiscovering => 'Start discovering people in the cosmos!';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get notifications => 'Notifications';

  @override
  String get privacy => 'Privacy';

  @override
  String get about => 'About';

  @override
  String get logout => 'Logout';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get done => 'Done';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get noResults => 'No results found';

  @override
  String get pullToRefresh => 'Pull to refresh';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get welcomeTitle => 'Welcome to Wink';

  @override
  String get welcomeSubtitle => 'Discover souls in the cosmos';

  @override
  String get loginWithGoogle => 'Continue with Google';

  @override
  String get loginWithApple => 'Continue with Apple';

  @override
  String get loginWithEmail => 'Continue with Email';

  @override
  String get termsAndPrivacy =>
      'By continuing, you agree to our Terms of Service and Privacy Policy';
}
