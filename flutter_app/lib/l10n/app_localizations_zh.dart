// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class L10nZh extends L10n {
  L10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '微客';

  @override
  String get discover => '发现';

  @override
  String get chat => '聊天';

  @override
  String get profile => '我的';

  @override
  String get square => '广场';

  @override
  String get settings => '设置';

  @override
  String get startChat => '开始聊天';

  @override
  String get typeMessage => '输入消息...';

  @override
  String get send => '发送';

  @override
  String get sending => '发送中...';

  @override
  String get messageSent => '消息已发送';

  @override
  String get messageError => '发送失败';

  @override
  String get typing => '正在输入...';

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String lastSeen(String time) {
    return '最后在线 $time';
  }

  @override
  String get photoOption => '照片';

  @override
  String get videoOption => '视频';

  @override
  String get voiceOption => '语音';

  @override
  String get cameraOption => '拍照';

  @override
  String get galleryOption => '相册';

  @override
  String get intimacyStranger => '陌生人';

  @override
  String get intimacyAcquaintance => '熟人';

  @override
  String get intimacyFriend => '朋友';

  @override
  String get intimacyClose => '亲密';

  @override
  String get intimacyIntimate => '知己';

  @override
  String intimacyGain(int points) {
    return '+$points';
  }

  @override
  String intimacyLevel(String level) {
    return '亲密度: $level';
  }

  @override
  String get aiLabel => 'AI';

  @override
  String get virtualPerson => '虚拟人';

  @override
  String messageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条消息',
      one: '1 条消息',
      zero: '暂无消息',
    );
    return '$_temp0';
  }

  @override
  String get newConversation => '新对话';

  @override
  String get noConversations => '还没有对话';

  @override
  String get startDiscovering => '开始在星空中发现新朋友吧！';

  @override
  String get language => '语言';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get darkMode => '深色模式';

  @override
  String get notifications => '通知';

  @override
  String get privacy => '隐私';

  @override
  String get about => '关于';

  @override
  String get logout => '退出登录';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get done => '完成';

  @override
  String get next => '下一步';

  @override
  String get back => '返回';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get loading => '加载中...';

  @override
  String get error => '错误';

  @override
  String get noResults => '没有找到结果';

  @override
  String get pullToRefresh => '下拉刷新';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get welcomeTitle => '欢迎来到微客';

  @override
  String get welcomeSubtitle => '在星空中发现灵魂';

  @override
  String get loginWithGoogle => '使用 Google 登录';

  @override
  String get loginWithApple => '使用 Apple 登录';

  @override
  String get loginWithEmail => '使用邮箱登录';

  @override
  String get termsAndPrivacy => '继续即表示您同意我们的服务条款和隐私政策';
}
