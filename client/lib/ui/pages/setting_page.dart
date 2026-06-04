import 'package:flutter/material.dart';

import '../services/auth_api.dart';
import '../services/capsule_notification_service.dart';
import '../services/push_notification_service.dart';
import '../services/settings_preferences.dart';
import 'friends_page.dart';
import 'login/login_page.dart';

enum _SettingsDetail {
  profile,
  friends,
  notifications,
  privacy,
  appInfo,
  help,
  terms,
  privacyPolicy,
  faq,
}

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  static const Color _backgroundColor = Color(0xFFFFF6E6);
  static const Color _brown = Color(0xFF765142);
  static const Color _darkText = Color(0xFF2E2B2A);
  static const Color _mutedText = Color(0xFF9A786A);
  static const Color _avatarFill = Color(0xFFFFC989);
  static const Color _chevronColor = Color(0xFFB7A59C);

  final AuthApi _authApi = AuthApi();
  String? _profileDisplayName;
  String _profileStatusMessage =
      SettingsPreferences.defaultProfileStatusMessage;
  NotificationSettings _notificationSettings = const NotificationSettings(
    pushEnabled: true,
    capsuleOpenEnabled: true,
    eventEnabled: false,
  );
  _SettingsDetail? _activeDetail;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _profileDisplayName = AuthApi.currentUsername;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final String statusMessage =
        await SettingsPreferences.getProfileStatusMessage();
    final NotificationSettings notificationSettings =
        await SettingsPreferences.getNotificationSettings();
    final String? displayName =
        AuthApi.currentUsername ?? await _authApi.refreshCurrentUsername();
    if (!mounted) {
      return;
    }

    setState(() {
      _profileStatusMessage = statusMessage;
      _notificationSettings = notificationSettings;
      if (displayName != null && displayName.isNotEmpty) {
        _profileDisplayName = displayName;
      }
    });
  }

  Future<void> _saveProfile({
    required String displayName,
    required String statusMessage,
  }) async {
    final String normalizedName = displayName.trim();
    final String normalizedStatus = statusMessage.trim();
    if (normalizedName.isEmpty) {
      _showSnackBar('닉네임을 입력해주세요.');
      return;
    }

    try {
      final String savedName = await _authApi.updateCurrentUserProfile(
        username: normalizedName,
      );
      await SettingsPreferences.setProfileStatusMessage(normalizedStatus);
      if (!mounted) {
        return;
      }

      setState(() {
        _profileDisplayName = savedName;
        _profileStatusMessage = normalizedStatus.isEmpty
            ? SettingsPreferences.defaultProfileStatusMessage
            : normalizedStatus;
      });
      _showSnackBar('프로필을 저장했습니다.');
    } on AuthApiException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('프로필 저장 중 오류가 발생했습니다.');
    }
  }

  Future<void> _togglePushNotification(bool enabled) async {
    await SettingsPreferences.setPushEnabled(enabled);
    if (!mounted) {
      return;
    }

    setState(() {
      _notificationSettings = _notificationSettings.copyWith(
        pushEnabled: enabled,
      );
    });

    if (enabled) {
      await PushNotificationService.instance.syncTokenWithServer();
    } else {
      await PushNotificationService.instance.deactivateCurrentDeviceToken();
    }
  }

  Future<void> _toggleCapsuleOpenNotification(bool enabled) async {
    await SettingsPreferences.setCapsuleOpenAlertEnabled(enabled);
    if (!enabled) {
      await CapsuleNotificationService.cancelAllAlerts();
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _notificationSettings = _notificationSettings.copyWith(
        capsuleOpenEnabled: enabled,
      );
    });
  }

  Future<void> _toggleEventNotification(bool enabled) async {
    await SettingsPreferences.setEventAlertEnabled(enabled);
    if (!mounted) {
      return;
    }

    setState(() {
      _notificationSettings = _notificationSettings.copyWith(
        eventEnabled: enabled,
      );
    });
  }

  void _showDetail(_SettingsDetail detail) {
    setState(() {
      _activeDetail = detail;
    });
  }

  void _hideDetail() {
    setState(() {
      _activeDetail = null;
    });
  }

  void _showUnavailable(String featureName) {
    _showSnackBar('$featureName 기능은 아직 준비 중입니다.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) {
      return;
    }

    final bool shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('로그아웃'),
              content: const Text('이 기기에서 로그아웃할까요?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('로그아웃'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    await PushNotificationService.instance.deactivateCurrentDeviceToken();
    await AuthApi.clearSessionAndStorage();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (BuildContext context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final _SettingsDetail? activeDetail = _activeDetail;
    if (activeDetail != null) {
      return _buildDetail(activeDetail);
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: ColoredBox(
        color: _backgroundColor,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: <Widget>[
            const _RoofAsset(),
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 30, 34, 36),
              child: Column(
                children: <Widget>[
                  _ProfilePanel(
                    displayName:
                        _profileDisplayName ?? AuthApi.currentUsername ?? '사용자',
                    statusMessage: _profileStatusMessage,
                    onTap: () => _showDetail(_SettingsDetail.profile),
                  ),
                  const SizedBox(height: 36),
                  _SettingsMenu(
                    onFriendsTap: () => _showDetail(_SettingsDetail.friends),
                    onNotificationsTap: () =>
                        _showDetail(_SettingsDetail.notifications),
                    onPrivacyTap: () => _showDetail(_SettingsDetail.privacy),
                    onAppInfoTap: () => _showDetail(_SettingsDetail.appInfo),
                    onHelpTap: () => _showDetail(_SettingsDetail.help),
                  ),
                  const SizedBox(height: 38),
                  _LogoutPanel(
                    isLoggingOut: _isLoggingOut,
                    onTap: _isLoggingOut ? null : _handleLogout,
                  ),
                  const SizedBox(height: 44),
                  const Center(
                    child: Text(
                      'TORI CAPSULE v1.0.0',
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(_SettingsDetail detail) {
    switch (detail) {
      case _SettingsDetail.profile:
        return _ProfileSettingsDetail(
          displayName: _profileDisplayName ?? AuthApi.currentUsername ?? '',
          statusMessage: _profileStatusMessage,
          onBack: _hideDetail,
          onSave: _saveProfile,
          onImageTap: () => _showUnavailable('프로필 이미지 변경'),
        );
      case _SettingsDetail.friends:
        return FriendsPage(onBack: _hideDetail);
      case _SettingsDetail.notifications:
        return _NotificationSettingsDetail(
          settings: _notificationSettings,
          onBack: _hideDetail,
          onPushChanged: _togglePushNotification,
          onCapsuleOpenChanged: _toggleCapsuleOpenNotification,
          onEventChanged: _toggleEventNotification,
        );
      case _SettingsDetail.privacy:
        return _PrivacySettingsDetail(
          onBack: _hideDetail,
          onPasswordTap: () => _showUnavailable('비밀번호 변경'),
          onBlockedUsersTap: () => _showUnavailable('차단된 사용자 관리'),
          onDeleteAccountTap: () => _showUnavailable('회원 탈퇴'),
        );
      case _SettingsDetail.appInfo:
        return _AppInfoSettingsDetail(
          onBack: _hideDetail,
          onTermsTap: () => _showDetail(_SettingsDetail.terms),
          onPrivacyPolicyTap: () => _showDetail(_SettingsDetail.privacyPolicy),
        );
      case _SettingsDetail.help:
        return _HelpSettingsDetail(
          onBack: _hideDetail,
          onFaqTap: () => _showDetail(_SettingsDetail.faq),
          onContactTap: () => _showUnavailable('1:1 문의하기'),
        );
      case _SettingsDetail.terms:
        return _TermsSettingsDetail(
          onBack: () => _showDetail(_SettingsDetail.appInfo),
        );
      case _SettingsDetail.privacyPolicy:
        return _PrivacyPolicySettingsDetail(
          onBack: () => _showDetail(_SettingsDetail.appInfo),
        );
      case _SettingsDetail.faq:
        return _FaqSettingsDetail(
          onBack: () => _showDetail(_SettingsDetail.help),
        );
    }
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.displayName,
    required this.statusMessage,
    required this.onTap,
  });

  final String displayName;
  final String statusMessage;
  final VoidCallback onTap;

  static const Color _brown = _SettingPageState._brown;
  static const Color _darkText = _SettingPageState._darkText;
  static const Color _mutedText = _SettingPageState._mutedText;
  static const Color _avatarFill = _SettingPageState._avatarFill;
  static const Color _chevronColor = _SettingPageState._chevronColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 126,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(color: Color(0x1A765142), offset: Offset(5, 5)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Row(
              children: <Widget>[
                Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                    color: _avatarFill,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Color(0xFFFFD9A8),
                        offset: Offset(-5, -5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: _brown,
                    size: 44,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _darkText,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        statusMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _mutedText,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _chevronColor, size: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu({
    required this.onFriendsTap,
    required this.onNotificationsTap,
    required this.onPrivacyTap,
    required this.onAppInfoTap,
    required this.onHelpTap,
  });

  final VoidCallback onFriendsTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback onAppInfoTap;
  final VoidCallback onHelpTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          _SettingsMenuRow(
            icon: Icons.diversity_3_outlined,
            label: '친구 관리',
            onTap: onFriendsTap,
          ),
          const _SettingsDivider(),
          _SettingsMenuRow(
            icon: Icons.notifications_none,
            label: '알림 설정',
            onTap: onNotificationsTap,
          ),
          const _SettingsDivider(),
          _SettingsMenuRow(
            icon: Icons.lock_outline,
            label: '개인정보 설정',
            onTap: onPrivacyTap,
          ),
          const _SettingsDivider(),
          _SettingsMenuRow(
            icon: Icons.info_outline,
            label: '앱 정보',
            onTap: onAppInfoTap,
          ),
          const _SettingsDivider(),
          _SettingsMenuRow(
            icon: Icons.help_outline,
            label: '도움말',
            onTap: onHelpTap,
          ),
        ],
      ),
    );
  }
}

class _SettingsMenuRow extends StatelessWidget {
  const _SettingsMenuRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  static const Color _brown = _SettingPageState._brown;
  static const Color _darkText = _SettingPageState._darkText;
  static const Color _chevronColor = _SettingPageState._chevronColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: <Widget>[
                Icon(icon, color: _brown, size: 32),
                const SizedBox(width: 22),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: _chevronColor, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 4,
      child: ColoredBox(color: _SettingPageState._brown),
    );
  }
}

class _LogoutPanel extends StatelessWidget {
  const _LogoutPanel({required this.isLoggingOut, required this.onTap});

  final bool isLoggingOut;
  final VoidCallback? onTap;

  static const Color _brown = _SettingPageState._brown;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 70,
          child: Center(
            child: isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _brown,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.logout_rounded, color: _brown, size: 30),
                      SizedBox(width: 14),
                      Text(
                        '로그아웃',
                        style: TextStyle(
                          color: _brown,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDetailShell extends StatelessWidget {
  const _SettingsDetailShell({
    required this.onBack,
    required this.child,
    this.contentTopGap = 34,
  });

  final VoidCallback onBack;
  final Widget child;
  final double contentTopGap;

  static const Color _backgroundColor = _SettingPageState._backgroundColor;
  static const Color _darkText = _SettingPageState._darkText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: ColoredBox(
        color: _backgroundColor,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: <Widget>[
            const _RoofAsset(),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 30, 30, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBack,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.chevron_left, color: _darkText, size: 32),
                        SizedBox(width: 2),
                        Text(
                          '뒤로',
                          style: TextStyle(
                            color: _darkText,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: contentTopGap),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoofAsset extends StatelessWidget {
  const _RoofAsset();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Image.asset(
        'assets/images/auth/asset.png',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    );
  }
}

class _SettingsDetailPanel extends StatelessWidget {
  const _SettingsDetailPanel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(color: Color(0x1A765142), offset: Offset(5, 5)),
        ],
      ),
      padding: padding ?? const EdgeInsets.fromLTRB(28, 30, 28, 30),
      child: child,
    );
  }
}

class _ProfileSettingsDetail extends StatefulWidget {
  const _ProfileSettingsDetail({
    required this.displayName,
    required this.statusMessage,
    required this.onBack,
    required this.onSave,
    required this.onImageTap,
  });

  final String displayName;
  final String statusMessage;
  final VoidCallback onBack;
  final Future<void> Function({
    required String displayName,
    required String statusMessage,
  })
  onSave;
  final VoidCallback onImageTap;

  @override
  State<_ProfileSettingsDetail> createState() => _ProfileSettingsDetailState();
}

class _ProfileSettingsDetailState extends State<_ProfileSettingsDetail> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _statusMessageController;
  bool _isSaving = false;

  static const Color _brown = _SettingPageState._brown;
  static const Color _avatarFill = _SettingPageState._avatarFill;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.displayName);
    _statusMessageController = TextEditingController(
      text: widget.statusMessage,
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _statusMessageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    await widget.onSave(
      displayName: _displayNameController.text,
      statusMessage: _statusMessageController.text,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: widget.onBack,
      contentTopGap: 32,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(32, 34, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('프로필 설정'),
            const SizedBox(height: 34),
            Center(
              child: Column(
                children: <Widget>[
                  Container(
                    width: 102,
                    height: 102,
                    decoration: const BoxDecoration(
                      color: _avatarFill,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0xFFFFD9A8),
                          offset: Offset(-5, -5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: _brown,
                      size: 58,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onImageTap,
                    child: const Text(
                      '이미지 변경',
                      style: TextStyle(
                        color: _brown,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            const _FieldLabel('닉네임'),
            const SizedBox(height: 12),
            _PixelTextField(controller: _displayNameController),
            const SizedBox(height: 28),
            const _FieldLabel('상태 메시지'),
            const SizedBox(height: 12),
            _PixelTextField(controller: _statusMessageController),
            const SizedBox(height: 42),
            _PixelActionButton(
              label: '저장하기',
              isLoading: _isSaving,
              onTap: _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSettingsDetail extends StatelessWidget {
  const _NotificationSettingsDetail({
    required this.settings,
    required this.onBack,
    required this.onPushChanged,
    required this.onCapsuleOpenChanged,
    required this.onEventChanged,
  });

  final NotificationSettings settings;
  final VoidCallback onBack;
  final Future<void> Function(bool enabled) onPushChanged;
  final Future<void> Function(bool enabled) onCapsuleOpenChanged;
  final Future<void> Function(bool enabled) onEventChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: onBack,
      contentTopGap: 30,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('알림 설정'),
            const SizedBox(height: 22),
            _PixelCheckboxRow(
              label: '푸시 알림',
              value: settings.pushEnabled,
              onChanged: onPushChanged,
            ),
            const _ThickDivider(),
            _PixelCheckboxRow(
              label: '캡슐 개봉 알림',
              value: settings.capsuleOpenEnabled,
              onChanged: onCapsuleOpenChanged,
            ),
            const _ThickDivider(),
            _PixelCheckboxRow(
              label: '이벤트 알림',
              value: settings.eventEnabled,
              onChanged: onEventChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySettingsDetail extends StatelessWidget {
  const _PrivacySettingsDetail({
    required this.onBack,
    required this.onPasswordTap,
    required this.onBlockedUsersTap,
    required this.onDeleteAccountTap,
  });

  final VoidCallback onBack;
  final VoidCallback onPasswordTap;
  final VoidCallback onBlockedUsersTap;
  final VoidCallback onDeleteAccountTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: onBack,
      contentTopGap: 30,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('개인정보 설정'),
            const SizedBox(height: 24),
            _ThinSettingsRow(label: '비밀번호 변경', onTap: onPasswordTap),
            _ThinSettingsRow(label: '차단된 사용자 관리', onTap: onBlockedUsersTap),
            _ThinSettingsRow(
              label: '회원 탈퇴',
              onTap: onDeleteAccountTap,
              textColor: const Color(0xFF8E5555),
              showBottomLine: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppInfoSettingsDetail extends StatelessWidget {
  const _AppInfoSettingsDetail({
    required this.onBack,
    required this.onTermsTap,
    required this.onPrivacyPolicyTap,
  });

  final VoidCallback onBack;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyPolicyTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: onBack,
      contentTopGap: 30,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('앱 정보'),
            const SizedBox(height: 20),
            const _AppVersionRow(),
            const _ThickDivider(),
            _ChevronSettingsRow(label: '이용약관', onTap: onTermsTap),
            const _ThickDivider(),
            _ChevronSettingsRow(label: '개인정보 처리방침', onTap: onPrivacyPolicyTap),
          ],
        ),
      ),
    );
  }
}

class _HelpSettingsDetail extends StatelessWidget {
  const _HelpSettingsDetail({
    required this.onBack,
    required this.onFaqTap,
    required this.onContactTap,
  });

  final VoidCallback onBack;
  final VoidCallback onFaqTap;
  final VoidCallback onContactTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: onBack,
      contentTopGap: 30,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('도움말'),
            const SizedBox(height: 20),
            _ThinSettingsRow(label: '자주 묻는 질문 (FAQ)', onTap: onFaqTap),
            _ThinSettingsRow(
              label: '1:1 문의하기',
              onTap: onContactTap,
              showBottomLine: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsSettingsDetail extends StatelessWidget {
  const _TermsSettingsDetail({required this.onBack});

  final VoidCallback onBack;

  static const List<_LegalArticle> _articles = <_LegalArticle>[
    _LegalArticle(
      title: '제1조 (목적)',
      body:
          '이 약관은 토리캡슐(이하 "회사")이 제공하는 모바일 애플리케이션 서비스(이하 "서비스")의 이용과 관련하여 '
          '회사와 이용자의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.',
    ),
    _LegalArticle(
      title: '제2조 (정의)',
      body:
          '1. "서비스"란 위치 기반으로 추억(글, 사진, 음악 등)을 캡슐 형태로 저장하고, 지정된 시점에 다시 열어볼 수 있도록 '
          '제공되는 일체의 서비스를 말합니다.\n'
          '2. "이용자"란 본 약관에 동의하고 서비스를 이용하는 자를 말합니다.\n'
          '3. "캡슐"이란 이용자가 작성·등록한 콘텐츠와 위치 정보를 묶어 보관한 단위 데이터를 말합니다.',
    ),
    _LegalArticle(
      title: '제3조 (약관의 효력 및 변경)',
      body:
          '1. 본 약관은 이용자가 회원가입 시 동의함으로써 효력이 발생합니다.\n'
          '2. 회사는 관련 법령에 위배되지 않는 범위에서 약관을 변경할 수 있으며, 변경 시에는 시행일 7일 이전부터 '
          '서비스 내 공지를 통해 안내합니다.',
    ),
    _LegalArticle(
      title: '제4조 (서비스의 제공)',
      body:
          '회사는 다음과 같은 서비스를 제공합니다.\n'
          '· 위치 기반 타임캡슐 생성·저장·개봉 기능\n'
          '· 친구와의 그룹 캡슐 공유 기능\n'
          '· 관광지 발견 및 AR 인증 기능\n'
          '· 기타 회사가 추가로 개발하거나 제휴를 통해 제공하는 서비스',
    ),
    _LegalArticle(
      title: '제5조 (이용자의 의무)',
      body:
          '이용자는 다음 행위를 하여서는 안 됩니다.\n'
          '· 타인의 개인정보 또는 명예를 침해하는 콘텐츠 등록\n'
          '· 음란물, 폭력적 콘텐츠 등 공서양속에 반하는 자료 게시\n'
          '· 서비스의 정상적인 운영을 방해하는 행위\n'
          '· 타인의 계정을 도용하거나 위치 정보를 조작하는 행위',
    ),
    _LegalArticle(
      title: '제6조 (게시물의 관리)',
      body:
          '회사는 이용자가 등록한 콘텐츠가 본 약관 또는 관련 법령에 위배된다고 판단되는 경우, 사전 통지 없이 '
          '해당 콘텐츠를 비공개 처리하거나 삭제할 수 있습니다.',
    ),
    _LegalArticle(
      title: '제7조 (서비스의 중단)',
      body:
          '회사는 시스템 점검, 천재지변, 통신장애 등 부득이한 사유가 발생한 경우 서비스 제공을 일시적으로 중단할 수 있으며, '
          '이로 인한 손해에 대해서는 고의 또는 중대한 과실이 없는 한 책임을 지지 않습니다.',
    ),
    _LegalArticle(
      title: '제8조 (책임의 제한)',
      body:
          '회사는 이용자 간 또는 이용자와 제3자 간에 서비스를 매개로 발생한 분쟁에 대해서는 개입할 의무가 없으며, '
          '이로 인한 손해를 배상할 책임을 지지 않습니다.',
    ),
    _LegalArticle(
      title: '부칙',
      body: '본 약관은 2026년 1월 1일부터 시행됩니다.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: onBack,
      contentTopGap: 28,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('이용약관'),
            const SizedBox(height: 18),
            for (int i = 0; i < _articles.length; i++) ...<Widget>[
              _LegalSection(article: _articles[i]),
              if (i < _articles.length - 1) const SizedBox(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrivacyPolicySettingsDetail extends StatelessWidget {
  const _PrivacyPolicySettingsDetail({required this.onBack});

  final VoidCallback onBack;

  static const List<_LegalArticle> _sections = <_LegalArticle>[
    _LegalArticle(
      title: '1. 수집·이용 목적',
      body:
          '토리캡슐은 회원가입 및 본인 확인, 위치 기반 캡슐 서비스 제공, 친구 기능 및 알림 전송, '
          '서비스 이용 분석을 통한 품질 개선 등의 목적으로 개인정보를 수집·이용합니다.',
    ),
    _LegalArticle(
      title: '2. 수집하는 항목',
      body:
          '· 필수 항목: 이메일, 닉네임, 비밀번호(암호화 저장)\n'
          '· 캡슐 등록 시: 사용자가 입력한 글·사진·동영상·음악, 캡슐을 묻은 위치(위·경도)\n'
          '· 디바이스 정보: OS 버전, 푸시 알림 토큰(FCM)\n'
          '· 선택 항목: 프로필 이미지, 상태 메시지',
    ),
    _LegalArticle(
      title: '3. 보유 및 이용 기간',
      body:
          '회원 탈퇴 시 지체 없이 개인정보를 파기합니다. 다만 관계 법령에서 보존 의무를 정한 경우에는 '
          '해당 기간 동안 안전하게 분리 보관 후 파기합니다.',
    ),
    _LegalArticle(
      title: '4. 제3자 제공',
      body:
          '회사는 이용자의 동의 없이 개인정보를 제3자에게 제공하지 않습니다. 다만, 법령에 따라 수사기관 등이 '
          '요청하는 경우에는 적법한 절차에 따라 제공할 수 있습니다.',
    ),
    _LegalArticle(
      title: '5. 처리 위탁',
      body:
          '안정적인 서비스 제공을 위해 다음 업무를 외부에 위탁하고 있습니다.\n'
          '· Mapbox: 지도 타일 렌더링\n'
          '· Firebase Cloud Messaging: 푸시 알림 전송\n'
          '· 클라우드 호스팅 사업자: 데이터 저장 및 백업',
    ),
    _LegalArticle(
      title: '6. 이용자의 권리',
      body:
          '이용자는 언제든지 본인의 개인정보를 조회·수정·삭제할 수 있으며, 회원 탈퇴를 통해 처리 정지를 '
          '요청할 수 있습니다. 위치 정보 수집은 디바이스의 위치 권한을 통해 직접 제어할 수 있습니다.',
    ),
    _LegalArticle(
      title: '7. 안전성 확보 조치',
      body:
          '비밀번호는 일방향 암호화하여 저장하며, 서버와의 모든 통신은 HTTPS로 암호화됩니다. '
          '개인정보 접근 권한은 최소한의 인원으로 제한하고, 정기적인 보안 점검을 수행합니다.',
    ),
    _LegalArticle(
      title: '8. 개인정보 보호 책임자',
      body:
          '· 책임자: 토리캡슐 운영팀\n'
          '· 문의: privacy@tori-capsule.me\n'
          '본 방침은 2026년 1월 1일부터 적용됩니다.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: onBack,
      contentTopGap: 28,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('개인정보 처리방침'),
            const SizedBox(height: 18),
            for (int i = 0; i < _sections.length; i++) ...<Widget>[
              _LegalSection(article: _sections[i]),
              if (i < _sections.length - 1) const SizedBox(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _FaqSettingsDetail extends StatefulWidget {
  const _FaqSettingsDetail({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_FaqSettingsDetail> createState() => _FaqSettingsDetailState();
}

class _FaqSettingsDetailState extends State<_FaqSettingsDetail> {
  static const List<_FaqEntry> _entries = <_FaqEntry>[
    _FaqEntry(
      question: '타임캡슐은 어떻게 만드나요?',
      answer:
          '하단 가운데의 + 버튼을 누르면 캡슐 만들기가 시작됩니다. 혼자/그룹 캡슐을 고른 뒤 글, 사진, 음악을 담아 '
          '현재 위치에 묻을 수 있어요. 묻은 캡슐은 지도 탭에 마커로 표시됩니다.',
    ),
    _FaqEntry(
      question: '캡슐은 언제 다시 열 수 있나요?',
      answer:
          '캡슐을 만들 때 "잠금 시점"을 설정할 수 있습니다. 잠금을 켜지 않으면 언제든 다시 열어볼 수 있고, '
          '날짜·시간을 지정하면 해당 시점이 지나야 내용이 보입니다. 친구와 함께 묻은 그룹 캡슐은 모든 멤버가 '
          '동의해야 미리 열 수 있어요.',
    ),
    _FaqEntry(
      question: '친구와 함께 캡슐을 묻으려면 어떻게 해야 하나요?',
      answer:
          '캡슐 만들기에서 "그룹 캡슐"을 선택한 뒤, 미리 친구 목록에 추가해 둔 사람을 선택하면 됩니다. '
          '친구 추가는 [설정 → 친구 관리]에서 닉네임으로 검색해 신청할 수 있어요.',
    ),
    _FaqEntry(
      question: '관광지는 어떻게 발견하나요?',
      answer:
          '지도에서 ?로 표시된 위치 근처에 가면 "관광지" 버튼이 활성화됩니다. 버튼을 누르거나 AR 화면에서 '
          '직접 인증하면 해당 장소가 발견 완료로 바뀌고, 캡슐 디자인이 잠금 해제될 수 있어요.',
    ),
    _FaqEntry(
      question: '지도 마커가 겹쳐 보일 때는 어떻게 하나요?',
      answer:
          '가까이 있는 마커들은 자동으로 묶여 숫자가 표시됩니다. 숫자를 누르면 해당 위치의 캡슐·관광지 목록이 '
          '뜨고, 원하는 항목을 선택하면 상세 화면으로 이동합니다. 지도를 확대해도 자연스럽게 풀려요.',
    ),
    _FaqEntry(
      question: '왜 위치 권한이 필요한가요?',
      answer:
          '캡슐은 "현재 위치에 묻는" 서비스이기 때문에 위치 권한이 필수입니다. 권한이 없으면 캡슐을 묻거나 '
          '근처 관광지를 발견할 수 없어요. 위치 정보는 캡슐 좌표와 발견 인증에만 사용되며, 별도로 추적하지 않습니다.',
    ),
    _FaqEntry(
      question: '알림이 오지 않아요.',
      answer:
          '[설정 → 알림 설정]에서 푸시 알림과 캡슐 개봉 알림이 모두 켜져 있는지 확인해주세요. 디바이스의 '
          'OS 설정에서 토리캡슐 알림이 차단되어 있는 경우에도 알림이 도착하지 않을 수 있습니다.',
    ),
    _FaqEntry(
      question: '계정을 삭제하고 싶어요.',
      answer:
          '[설정 → 개인정보 설정 → 회원 탈퇴]를 통해 요청할 수 있습니다. 탈퇴가 완료되면 등록한 캡슐과 '
          '프로필 정보가 모두 삭제되며 복구할 수 없으므로 신중히 진행해주세요.',
    ),
  ];

  final Set<int> _expanded = <int>{0};

  void _toggle(int index) {
    setState(() {
      if (_expanded.contains(index)) {
        _expanded.remove(index);
      } else {
        _expanded.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: widget.onBack,
      contentTopGap: 28,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('자주 묻는 질문 (FAQ)'),
            const SizedBox(height: 18),
            for (int i = 0; i < _entries.length; i++)
              _FaqRow(
                entry: _entries[i],
                isOpen: _expanded.contains(i),
                onTap: () => _toggle(i),
                showDivider: i < _entries.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _LegalArticle {
  const _LegalArticle({required this.title, required this.body});

  final String title;
  final String body;
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.article});

  final _LegalArticle article;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          article.title,
          style: const TextStyle(
            color: _SettingPageState._darkText,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          article.body,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _FaqEntry {
  const _FaqEntry({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.entry,
    required this.isOpen,
    required this.onTap,
    required this.showDivider,
  });

  final _FaqEntry entry;
  final bool isOpen;
  final VoidCallback onTap;
  final bool showDivider;

  static const Color _brown = _SettingPageState._brown;
  static const Color _darkText = _SettingPageState._darkText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Q',
                  style: TextStyle(
                    color: _brown,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.question,
                    style: const TextStyle(
                      color: _darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  color: _brown,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 4, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'A',
                  style: TextStyle(
                    color: Color(0xFF8E5555),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.answer,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
          crossFadeState:
              isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
        if (showDivider)
          Container(
            height: 1,
            color: const Color(0xFFD7C8BF),
          ),
      ],
    );
  }
}

class _DetailTitle extends StatelessWidget {
  const _DetailTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _SettingPageState._darkText,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF334155),
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PixelTextField extends StatelessWidget {
  const _PixelTextField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFD7C8BF), width: 1)),
      ),
      padding: const EdgeInsets.only(left: 16),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        maxLines: 1,
        style: const TextStyle(
          color: _SettingPageState._darkText,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

class _PixelActionButton extends StatelessWidget {
  const _PixelActionButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  static const Color _brown = _SettingPageState._brown;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          color: _brown,
          boxShadow: <BoxShadow>[
            BoxShadow(color: Color(0xFF5A372B), offset: Offset(5, 5)),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class _PixelCheckboxRow extends StatelessWidget {
  const _PixelCheckboxRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Future<void> Function(bool enabled) onChanged;

  static const Color _brown = _SettingPageState._brown;
  static const Color _darkText = _SettingPageState._darkText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: SizedBox(
        height: 76,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _darkText,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: value ? _brown : Colors.white,
                border: Border.all(
                  color: value ? _brown : const Color(0xFF777777),
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, color: Colors.white, size: 24)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinSettingsRow extends StatelessWidget {
  const _ThinSettingsRow({
    required this.label,
    required this.onTap,
    this.textColor = _SettingPageState._darkText,
    this.showBottomLine = true,
  });

  final String label;
  final VoidCallback onTap;
  final Color textColor;
  final bool showBottomLine;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          border: showBottomLine
              ? const Border(
                  bottom: BorderSide(color: Color(0xFFD7C8BF), width: 1),
                )
              : null,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ChevronSettingsRow extends StatelessWidget {
  const _ChevronSettingsRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9AA3AF), size: 30),
          ],
        ),
      ),
    );
  }
}

class _AppVersionRow extends StatelessWidget {
  const _AppVersionRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 58,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '버전',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            'v1.0.0 (최신)',
            style: TextStyle(
              color: _SettingPageState._darkText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThickDivider extends StatelessWidget {
  const _ThickDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 4,
      child: ColoredBox(color: _SettingPageState._brown),
    );
  }
}
